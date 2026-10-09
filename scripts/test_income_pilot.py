"""Synthetic software checks only; these are not membership-validation evidence."""
import copy
import unittest

from evaluate_income_pilot import BANDS, REGIONS, evaluate

PILOT = set("abcdef")


def study(n=210):
    return {
        "schemaVersion": 1, "modelVersion": "synthetic-test-only",
        "candidateArtifactSHA256": "a" * 64,
        "independentHoldout": True, "synthetic": True, "trainingParticipantIDs": [],
        "records": [{"participantID": f"fixture_{i}", "consented": True,
                     "originRegion": REGIONS[i % 4], "areaIncomeBand": BANDS[i % 7],
                     "usesServiceIDs": list("def"), "doesNotUseServiceIDs": list("abc"),
                     "forgottenServiceIDs": list("def"), "baselineTop3": list("abc"),
                     "candidateTop3": list("def")} for i in range(n)]}


class IncomePilotEvaluationTests(unittest.TestCase):
    def run_study(self, data):
        return evaluate(data, PILOT, replicates=1000)

    def test_synthetic_cannot_pass_even_with_perfect_lift(self):
        result = self.run_study(study())
        self.assertEqual(result["households"], 210)
        self.assertEqual(result["usefulLiftLower95"], 1)
        self.assertEqual(result["irrelevantIncreaseUpper95"], -1)
        self.assertEqual(result["blockingReasons"], ["syntheticData"])
        self.assertFalse(result["passesNumericalGate"])
        self.assertFalse(result["releaseApproved"])

    def test_no_observations_cannot_pass(self):
        result = self.run_study(study(0))
        self.assertIsNone(result["usefulLiftLower95"])
        self.assertFalse(result["passesNumericalGate"])

    def test_training_leakage_and_duplicates_rejected(self):
        data = study(2)
        data["trainingParticipantIDs"] = ["fixture_0"]
        with self.assertRaisesRegex(ValueError, "overlaps"):
            self.run_study(data)
        data["trainingParticipantIDs"] = []
        data["records"].append(copy.deepcopy(data["records"][0]))
        with self.assertRaisesRegex(ValueError, "Duplicate household"):
            self.run_study(data)

    def test_conflicts_and_nonmember_forgotten_labels_rejected(self):
        data = study(1)
        data["records"][0]["doesNotUseServiceIDs"].append("d")
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            self.run_study(data)
        data = study(1)
        data["records"][0]["forgottenServiceIDs"].append("a")
        with self.assertRaisesRegex(ValueError, "explicit positive"):
            self.run_study(data)

    def test_unknown_answers_are_excluded_never_negative(self):
        data = study(2)
        data["records"][0]["doesNotUseServiceIDs"].remove("a")
        result = self.run_study(data)
        self.assertEqual(result["households"], 1)
        self.assertEqual(result["excludedCounts"], {"incompleteLabels": 1})
        self.assertIn("excludedRecordsRequireReview", result["blockingReasons"])

    def test_without_separate_research_consent_excluded(self):
        data = study(1)
        data["records"][0]["consented"] = False
        result = self.run_study(data)
        self.assertEqual(result["households"], 0)
        self.assertEqual(result["excludedHouseholds"], 1)

    def test_identical_rankings_do_not_establish_lift(self):
        data = study(7)
        for record in data["records"]:
            record["candidateTop3"] = record["baselineTop3"][:]
        result = self.run_study(data)
        self.assertEqual(result["usefulLiftLower95"], 0)
        self.assertIn("usefulLiftNotEstablished", result["blockingReasons"])

    def test_harm_in_subgroup_blocks(self):
        data = study()
        for record in data["records"]:
            if record["areaIncomeBand"] == "over200k":
                record["baselineTop3"], record["candidateTop3"] = record["candidateTop3"], record["baselineTop3"]
        result = self.run_study(data)
        self.assertGreater(result["usefulLiftLower95"], 0)
        self.assertIn("insufficientOrHarmedStratum:over200k", result["blockingReasons"])

    def test_bad_ids_short_rankings_and_incidental_personal_data_rejected(self):
        for key, value in (("baselineTop3", ["a", "b"]), ("candidateTop3", ["d", "e", "unknown"]),
                           ("email", "not-an-actual-email"), ("consented", "yes")):
            data = study(1)
            data["records"][0][key] = value
            with self.assertRaises(ValueError):
                self.run_study(data)

    def test_paired_bootstrap_is_reproducible(self):
        data = study(21)
        data["records"][0]["candidateTop3"] = list("abc")
        self.assertEqual(self.run_study(data), self.run_study(data))


if __name__ == "__main__":
    unittest.main()
