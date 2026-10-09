# Income and service-use pilot

Status: implementation and evaluation infrastructure, October 4, 2026. **No income coefficients are enabled.** No real membership model has been trained or validated.

## What customers can use now

- **Review services → Review recurring accounts** opens 25 optional questions covering children, home services, pets, shopping/deliveries, memberships and travel. The IDs and wording live in [IncomePilot.json](../../movingsoon.app/Resources/IncomePilot.json), alongside source mappings and their limits.
- “I use this,” “I don't use this,” and “Not sure” are stored locally, with a timestamp and question version. They are separate from whether an address-change task applies. Adding or dismissing a task never becomes a membership label.
- A positive answer raises an unhandled account's review priority; a negative answer hides the suggestion; unsure defers it for seven days. Adding a reminder is a separate action. Existing and completed tasks remain intact. Existing task decisions and reviewed-category choices still control automatic prompts.
- Census opt-in adds seven **area household income bands** to the origin/destination snapshot. Missing distribution data does not discard the core snapshot. Legacy cached snapshots remain readable offline.
- There is no research upload, app-data export, telemetry collection, backend or LLM for this pilot. Answering account questions does not enroll someone in research.

## Source assessment

| Source | Supported use | Limits / next integration work |
|---|---|---|
| [Census 2024 ACS B19001](https://api.census.gov/data/2024/acs/acs5/groups/B19001.html) | Origin/destination ZCTA household counts in income bands; estimates and margins of error | Describes an area, never the customer's income. No provider enrollment labels. Census requests now use 50 variables, including the existing household/housing measures. |
| [BLS Consumer Expenditure tables](https://www.bls.gov/cex/tables.htm) | Research mapping between broad expenditure categories, household composition and income groups | Spending means are not service membership probabilities or named-brand evidence. The 2024 income-quintile workbook download returned HTTP 403 during this work; no numeric BLS evidence or weights were extracted. The mapping remains provisional pending inspection of actual table rows and definitions. |
| [Esri Market Potential](https://doc.arcgis.com/en/esri-demographics/latest/esri-demographics/market-potential.htm) and [methodology](https://doc.arcgis.com/en/esri-demographics/latest/esri-demographics/market-potential-methodology.htm) | Candidate licensed source for researching category/brand coverage | Modeled local estimates are not independent observed service-use labels. Variables can describe adults or households; denominators must match the feature. An index of 100 is a national reference, not a probability. Exact 25-service coverage and permission for offline redistribution/derived weights are unverified. No data purchased or downloaded. |
| Separately consented survey or appropriately licensed observed service-use dataset | Potential training and independent validation labels | Not acquired. Must distinguish current service use, actual reminder usefulness and task applicability. Recruitment/survey and any sharing require their own explicit consent and documented rights. |

The resource file holds category hypotheses, not verified financial thresholds. No assertion such as “Life Time users earn over $200k” is encoded. It also includes non-fitness services such as childcare, tutoring, cleaning, pest control, pet insurance, deliveries and roadside assistance.

## Local ranking contract

Feature definition: `acs2024.originZCTA.householdIncomeShares.v1`.

1. Existing tasks, explicit task decisions and completed category reviews control whether to ask again.
2. Actual service-use and household answers lead the existing rule-based ranking. “I use this” can cover an account managed for someone outside the household.
3. A future approved association may add **at most ±4 ranking points**. This score only orders questions; it is not an enrollment probability. Destination income is never used to infer existing membership.
4. The income contribution requires Census opt-in, a matching origin ZIP, ACS 2020–2024 vintage, complete nonnegative counts, finite uncertainty, no future timestamp, and a snapshot no older than 90 days. Missing/uncertain data contributes nothing. Current uncertainty checks (each count MOE / total households ≤ 0.5) are provisional engineering limits, not confidence bounds on a customer's membership.
5. A rule requires a service-use survey source, approved offline use, matching feature/model versions, release review, valid dates, coefficients in [-1,1], and an independent non-synthetic validation report. Public Census, BLS and modeled-market estimates alone cannot enable it.
6. There are no bundled rules. With the current bundle, changing income distributions cannot change the question ranking.

Grouped count margins of error use a root-sum-square approximation. Percentages are displayed as descriptive shares, without a claim of precise percentage confidence intervals. ZIPs are matched to Census ZCTAs and not exact neighborhood boundaries.

## Study before enabling any rule

### 1. Define and freeze the candidate

Use documented observed service-use data to develop a small regularized model or shrinkage-based rule outside the app. Keep household IDs disjoint across development and validation; separate households that share accounts or recruit together. Reserve geography and/or a later period where feasible. Record sampling, weighting, coverage, label dates, feature vintage and source rights. Freeze the candidate artifact/hash and production-equivalent ranking code before viewing holdout labels. BLS category means alone do not train this model.

Compare the current rules with the same rules plus the proposed bounded income adjustment. Both arms must apply identical task exclusions, household inputs and diversity rules. A change in any of those is a separate experiment. Obtain a locked top-three list for each arm; don't tune the model against the holdout.

### 2. Collect independent labels

Recruit a separately consented sample across income-area bands and regions; choose sample size through a power and sampling review. **200 households, 20 per stratum and three regions are minimum software gates, not proof of adequate statistical power.** They may need to be increased before release.

Ask about current service use independently of app suggestions, and record which used accounts the household had overlooked and still needed to update. Avoid suggestion exposure contaminating the baseline “forgotten” label. A nonapplicable/completed task is not a negative service-use label. Skipped and unsure answers are unknown.

Record a household only once. Coarse `areaIncomeBand` represents the **origin ZCTA median-income band**, never inferred personal income. The proposed model uses the full seven-band distribution; this evaluation band is only for subgroup checks. Canadian households are outside this US Census pilot.

### 3. Evaluate offline

The command-line evaluator uses only an explicitly prepared study file. It never reads app storage. It outputs aggregate metrics and hashes, without household identifiers.

```sh
python3 scripts/evaluate_income_pilot.py /private/path/study.json \
  --output /private/path/evaluation.json
python3 -m unittest discover -s scripts -p 'test_*.py' -v
```

An existing output file is preserved. Exit 0 means the evaluation completed, **not** that the candidate passed. Inspect `passesNumericalGate`, `blockingReasons` and `releaseApproved`; approval is always false in generated reports. Exit 2 indicates invalid input or an I/O problem. Do not commit study files; keep licensed or consented data in a separately controlled location.

Required input fields (the evaluator rejects unexpected fields):

```json
{
  "schemaVersion": 1,
  "modelVersion": "FROZEN-CANDIDATE-VERSION",
  "candidateArtifactSHA256": "64-lowercase-hex-digits-from-the-frozen-artifact",
  "independentHoldout": true,
  "synthetic": false,
  "trainingParticipantIDs": [],
  "records": [
    {
      "participantID": "pseudonymous-household-id",
      "consented": true,
      "originRegion": "west",
      "areaIncomeBand": "from75to100k",
      "usesServiceIDs": ["lifetime", "aaa", "costco"],
      "doesNotUseServiceIDs": ["rover", "chewy", "instacart"],
      "forgottenServiceIDs": ["aaa"],
      "baselineTop3": ["rover", "chewy", "instacart"],
      "candidateTop3": ["lifetime", "aaa", "costco"]
    }
  ]
}
```

This illustrates the schema; it is not real data or a runnable passing study. `trainingParticipantIDs` must list development participants where applicable; a declaration of independence is not evidence of independence.

- Regions: `northeast`, `midwest`, `south`, `west` (US Census regions).
- Bands: `under35k`, `from35to50k`, `from50to75k`, `from75to100k`, `from100to150k`, `from150to200k`, `over200k` (last band includes $200,000).
- Both lists must contain exactly three unique pilot IDs. Every shown service needs an explicit positive or negative service-use label. Otherwise the household is excluded and exclusions block numerical readiness pending missingness review. Do not solve that gate by silently deleting excluded records.
- `forgottenServiceIDs` must be a subset of explicitly used services. Ask whether the address update remained undone before the review.
- Duplicate household IDs, training overlap, conflicting labels, unrecognized services and extra fields fail validation. The evaluator cannot detect identity reuse under different pseudonyms or dishonest metadata; study review is necessary.

**Metrics:** useful@3 = forgotten-and-used accounts / 3; irrelevant@3 = explicitly unused accounts / 3. Calculate candidate minus baseline for each household and use a seeded paired household bootstrap (default 5,000 replicates) for the 2.5th/97.5th percentile bounds. This is a reminder-order experiment, not a calibrated membership probability evaluation.

The provisional numerical gates require:

- Overall useful-lift lower bound > 0 and irrelevant-increase upper bound ≤ 0.
- At least 200 independent held-out households and three regions.
- Every income band and represented region has ≥20 households, useful-lift lower bound ≥0 and irrelevant-increase upper bound ≤0.
- Non-synthetic observations; no unresolved excluded households.

Intervals are exploratory percentile bootstrap intervals, without multiplicity correction, survey weights or a selection-bias correction. Results require statistical review, particularly for small or homogeneous strata. Additional precision/recall/calibration and per-service coverage checks belong in model-development review; this tool does not estimate household membership probabilities.

### 4. Review and package

Review sampling/label validity, uncertainty, subgroup results, provider-specific coverage, rights, missingness and production parity. Archive the exact report and its printed SHA256 with the candidate artifact. Recompute the hash during release review; the app checks its shape but cannot verify a report it does not ship. Copy the reviewed aggregate/stratum fields into `IncomeValidationReport` only after that review. Set `reviewedForRelease` and `offlineUseApproved` based on actual documented approvals, never on a synthetic test fixture. Package only coefficients and public/approved metadata, not household research records.

If evidence is weak, leave the affected service without a rule. The local account-review flow remains useful with no income model. A lightweight LLM is not needed for any step shipped here.
