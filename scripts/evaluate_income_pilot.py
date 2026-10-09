#!/usr/bin/env python3
"""Offline paired evaluation. Reads an explicitly prepared study file, never app data.

No model fitting, network access, household export, or automatic rule activation.
See research/income-pilot/README.md for the study contract and remaining reviews.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import random
import re
import statistics
import sys

BANDS = ("under35k", "from35to50k", "from50to75k", "from75to100k",
         "from100to150k", "from150to200k", "over200k")
REGIONS = ("northeast", "midwest", "south", "west")
MANIFEST = Path(__file__).resolve().parents[1] / "movingsoon.app/Resources/IncomePilot.json"
RECORD_FIELDS = {"participantID", "consented", "originRegion", "areaIncomeBand",
                 "usesServiceIDs", "doesNotUseServiceIDs", "forgottenServiceIDs",
                 "baselineTop3", "candidateTop3"}
STUDY_FIELDS = {"schemaVersion", "modelVersion", "candidateArtifactSHA256",
                "independentHoldout", "synthetic", "trainingParticipantIDs", "records"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def ids(value, allowed=None):
    require(isinstance(value, list) and all(isinstance(x, str) and x for x in value),
            "ID collections must be lists of nonempty strings")
    require(len(set(value)) == len(value), "Duplicate ID in an ID collection")
    require(allowed is None or set(value) <= allowed, "Service ID outside the frozen pilot")
    return set(value)


def percentile(sorted_values, quantile):
    index = (len(sorted_values) - 1) * quantile
    lower = int(index)
    upper = min(lower + 1, len(sorted_values) - 1)
    return sorted_values[lower] + (index - lower) * (sorted_values[upper] - sorted_values[lower])


def metrics(records, replicates, seed):
    if not records:
        return {"households": 0, "usefulLift": None, "irrelevantIncrease": None,
                "usefulLiftLower95": None, "irrelevantIncreaseUpper95": None}
    # Resample households as pairs; suggestions within a household aren't independent.
    rng = random.Random(seed)
    useful, irrelevant = [], []
    for _ in range(replicates):
        sample = rng.choices(records, k=len(records))
        useful.append(statistics.fmean(r[2] - r[1] for r in sample))
        irrelevant.append(statistics.fmean(r[4] - r[3] for r in sample))
    useful.sort()
    irrelevant.sort()
    return {
        "households": len(records),
        "baselineUsefulAt3": statistics.fmean(r[1] for r in records),
        "candidateUsefulAt3": statistics.fmean(r[2] for r in records),
        "baselineIrrelevantAt3": statistics.fmean(r[3] for r in records),
        "candidateIrrelevantAt3": statistics.fmean(r[4] for r in records),
        "usefulLift": statistics.fmean(r[2] - r[1] for r in records),
        "irrelevantIncrease": statistics.fmean(r[4] - r[3] for r in records),
        "usefulLiftLower95": percentile(useful, .025),
        "irrelevantIncreaseUpper95": percentile(irrelevant, .975),
    }


def evaluate(study, pilot_ids, replicates=5000, seed=20261004):
    require(isinstance(study, dict) and set(study) == STUDY_FIELDS,
            "Unexpected or missing study fields; see the study contract")
    require(type(study["schemaVersion"]) is int and study["schemaVersion"] == 1,
            "Unsupported schema version")
    require(isinstance(study["modelVersion"], str) and study["modelVersion"].strip(),
            "A frozen modelVersion is required")
    require(isinstance(study["candidateArtifactSHA256"], str)
            and re.fullmatch(r"[0-9a-f]{64}", study["candidateArtifactSHA256"]),
            "A frozen candidate artifact SHA256 is required")
    for flag in ("independentHoldout", "synthetic"):
        require(type(study[flag]) is bool, f"{flag} must be an explicit boolean")
    require(type(replicates) is int and replicates >= 1000, "Use at least 1000 bootstrap replicates")
    training = ids(study["trainingParticipantIDs"])
    require(isinstance(study["records"], list), "records must be a list")
    seen, paired, excluded = set(), [], Counter()
    for row in study["records"]:
        require(isinstance(row, dict) and set(row) == RECORD_FIELDS,
                "Unexpected or missing record fields; do not include addresses or exact income")
        participant = row["participantID"]
        require(isinstance(participant, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,80}", participant),
                "Use a pseudonymous participant ID")
        require(participant not in seen, "Duplicate household in holdout")
        require(participant not in training, "Training household overlaps holdout")
        seen.add(participant)
        require(type(row["consented"]) is bool, "consented must be an explicit boolean")
        if not row["consented"]:
            excluded["noResearchConsent"] += 1
            continue
        require(row["originRegion"] in REGIONS, "Unknown US Census origin region")
        require(row["areaIncomeBand"] in BANDS, "Unknown origin-area median-income band")
        used = ids(row["usesServiceIDs"], pilot_ids)
        unused = ids(row["doesNotUseServiceIDs"], pilot_ids)
        forgotten = ids(row["forgottenServiceIDs"], pilot_ids)
        baseline = ids(row["baselineTop3"], pilot_ids)
        candidate = ids(row["candidateTop3"], pilot_ids)
        require(not used & unused, "Conflicting service-use labels")
        require(forgotten <= used, "Forgotten services must have explicit positive service-use labels")
        require(len(baseline) == len(candidate) == 3, "Both frozen lists must contain three unique services")
        if not (baseline | candidate) <= (used | unused):
            excluded["incompleteLabels"] += 1
            continue
        paired.append((row, len(baseline & forgotten) / 3, len(candidate & forgotten) / 3,
                       len(baseline & unused) / 3, len(candidate & unused) / 3))

    aggregate = metrics(paired, replicates, seed)
    income = [{"id": band, **metrics([r for r in paired if r[0]["areaIncomeBand"] == band],
                                     replicates, seed + i + 1)} for i, band in enumerate(BANDS)]
    region = [{"id": name, **metrics([r for r in paired if r[0]["originRegion"] == name],
                                     replicates, seed + 100 + i)} for i, name in enumerate(REGIONS)
              if any(r[0]["originRegion"] == name for r in paired)]
    reasons = []
    if study["synthetic"]:
        reasons.append("syntheticData")
    if not study["independentHoldout"]:
        reasons.append("holdoutNotIndependent")
    if len(paired) < 200:
        reasons.append("fewerThan200Households")
    if len(region) < 3:
        reasons.append("fewerThan3Regions")
    if aggregate["usefulLiftLower95"] is None or aggregate["usefulLiftLower95"] <= 0:
        reasons.append("usefulLiftNotEstablished")
    if aggregate["irrelevantIncreaseUpper95"] is None or aggregate["irrelevantIncreaseUpper95"] > 0:
        reasons.append("irrelevanceMayIncrease")
    for group in income + region:
        if group["households"] < 20 or group["usefulLiftLower95"] is None \
                or group["usefulLiftLower95"] < 0 or group["irrelevantIncreaseUpper95"] > 0:
            reasons.append("insufficientOrHarmedStratum:" + group["id"])
    # Complete-case reports with exclusions require a missingness review. Do not
    # silently permit a biased subset to become a deployment-ready report.
    if excluded:
        reasons.append("excludedRecordsRequireReview")
    return {
        "schemaVersion": 1, "modelVersion": study["modelVersion"],
        "candidateArtifactSHA256": study["candidateArtifactSHA256"],
        "independentHoldout": study["independentHoldout"], "synthetic": study["synthetic"],
        **aggregate, "regionCount": len(region), "incomeStrata": income, "regionStrata": region,
        "excludedCounts": dict(excluded), "excludedHouseholds": sum(excluded.values()),
        "bootstrapReplicates": replicates, "seed": seed,
        "passesNumericalGate": not reasons, "blockingReasons": reasons,
        "releaseApproved": False,
        "reviewRequired": ["study design and sampling", "data rights and offline redistribution",
                           "candidate artifact and ranking parity", "missingness and subgroup uncertainty",
                           "reproducibility and release approval"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--replicates", type=int, default=5000)
    args = parser.parse_args()
    try:
        require(args.input.resolve() != args.output.resolve(), "Output must not overwrite study input")
        raw = args.input.read_bytes()
        pilot = {r["id"] for r in json.loads(MANIFEST.read_text())["services"]}
        report = evaluate(json.loads(raw), pilot, args.replicates)
        report["inputSHA256"] = hashlib.sha256(raw).hexdigest()
        report["pilotManifestSHA256"] = hashlib.sha256(MANIFEST.read_bytes()).hexdigest()
        encoded = (json.dumps(report, indent=2, allow_nan=False) + "\n").encode()
        # Exclusive creation preserves earlier evaluation evidence.
        with args.output.open("xb") as handle:
            handle.write(encoded)
        print(json.dumps({"reportSHA256": hashlib.sha256(encoded).hexdigest(),
                          "households": report["households"],
                          "passesNumericalGate": report["passesNumericalGate"],
                          "releaseApproved": False}))
    except (ValueError, OSError, TypeError, KeyError) as error:
        # Do not echo input contents or household identifiers.
        print("Evaluation failed: " + (str(error) if isinstance(error, ValueError)
                                      else type(error).__name__), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
