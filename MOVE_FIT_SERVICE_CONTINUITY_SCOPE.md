# Move Fit & Service Continuity

> **Implementation note (October 2026):** The dashboard shows a US ZIP/ZCTA comparison using 2020–2024 ACS 5-year aggregate estimates (median household income, average household size, and share of family households with 3+ people). Add Services now surfaces household-fit prompts and offers a user-triggered MapKit search for confirmed physical providers. Results are presented as map listings to verify, not proof of coverage or membership portability. Named children's activities, tutoring, pet delivery, and pet-sitting require explicit service confirmation; reporting children or pets alone adds only household-relevant move tasks. This remains an explainable first slice, not a catalog-wide adoption model: verified provider coverage and service-specific prevalence evidence are still unavailable in the app.

## Purpose

Help a household understand what may change when it moves and discover services it may have missed across MovingSoon's 100+ service catalog. Combine the household's stated profile, its selected services, origin/destination context, and service-specific audience/availability data to rank useful questions and actions. Keep recommendations explainable and user-confirmed.

This is a product direction and implementation scope. Area-level income and household composition can be useful predictors of which services are more common in a market, but they are not a measurement of an individual family's income or actual enrollment. The product should use them as one contextual signal among several, then ask the customer to confirm.

## Current baseline

- Onboarding collects an optional origin postal code, a destination postal code, and optional neighborhood labels.
- `LifestyleProfile` stores selected services and household signals. The interview includes children and child count, pets, and housing status.
- `ChecklistGenerator` uses confirmed lifestyle flags and selected financial institutions to create address-change tasks.
- `RegionalEconomicsService` bundles state-level median household income and home value; its cost-direction label is based on home-value change.
- `RegionalSimilarityService` combines those state figures with hand-curated regional archetypes into a hand-engineered similarity score.
- `MoveImpactEngine` suggests a small set of destination-archetype memberships not already selected. Origin/destination similarity can raise suggestion confidence. The user must confirm suggestions.
- Neighborhood lookup currently resolves names and coordinates; it does not score neighborhood quality or household demographics.
- Suggestion accept/reject events are queued locally with noise. There is no transmission path or learned personalization model.

### Existing UX and data-flow assessment

1. **Move intake:** `CoreIntakeView` asks for date, destination postal code/neighborhood, then optional origin postal code/neighborhood. Neighborhood lookup can save coordinates, but origin is optional and the ZIP-to-region fallback is state/city-bucket based. `EditMoveView` has its own validation path and should be included in any location-data audit.
2. **Household interview:** the three screens ask kids/count, pets/species, owning the new home, selected financial institutions, and a limited set of optional service chips. Much of the long-tail catalog is deferred to `AddMoreServicesView`. Named family activities/providers are individually confirmed there; a children flag no longer creates their tasks. Avoid turning first-run onboarding into a 100-item survey.
3. **Persistence:** `LifestyleProfile.activeFlags` is the source of truth for checklist filtering. Child count and pet species are additive fields. `Signal` records can label profile flags as self-reported, but the interview's bulk profile assignment relies on the existing lazy backfill.
4. **Task generation:** `ChecklistGenerator` is deterministic: explicit flags plus chosen financial institutions create tasks. Keep this boundary. An inferred candidate must not silently become an active flag or checklist task.
5. **Suggestions and feedback:** `MoveImpactEngine` currently emits only a narrow set of regional archetype candidates; the dashboard and add-services screen let the user accept/reject. The `PendingSignal`/`SignalEmitter` path hashes suggestion feedback into a noisy vector and keeps it on device. It has neither service-level structured labels nor a transmission/training path, so it cannot currently support calibrated catalog-wide predictions.

The key UX/data distinction is missing today: **confirmed service enrollment** and **possible relevance** need separate states. Do not overload `activeFlags` to represent both.

The dashboard's existing state-level home-value comparison is not a full cost-of-living measure, and `RegionalSimilarityService` combines state economics with archetype features using a hand-scaled cosine similarity. Neither result is a calibrated household-service propensity. `MoveImpactEngine` only uses the similarity score to upgrade some suggestion confidence when it exceeds a threshold; it does not predict enrollment. Area-level household size and the user's reported child count are now separately available, but must not be treated as equivalent measures.

Relevant implementation: `Models/Move.swift`, `Models/LifestyleProfile.swift`, `Services/ChecklistGenerator.swift`, `Services/MoveImpactEngine.swift`, `Services/RegionalEconomicsService.swift`, `Services/RegionalSimilarityService.swift`, `Services/GeocoderService.swift`, `Views/Dashboard/ZenDashboardView.swift`, and `Views/Settings/AddMoreServicesView.swift`.

## Product principle

Prefer **“What may change for your household?”** over **“Is this a better neighborhood?”**

Use location and demographics to improve **candidate discovery across the catalog**, not to make an unqualified claim that a particular family is enrolled in a service. For example, area income and household composition may change the ranking of optional suggestions when combined with the services the user already confirms. Show why each suggestion appeared and invite a simple yes/no/not sure response.

Area statistics describe an area, not the user. A selected premium gym may help identify a confirmed preference signal, but it must not be converted into a personal income estimate. Avoid a single destination grade. Show separate location factors with dates, geographic resolution, uncertainty, and user-controlled priorities.

## MVP scope

### 1. Catalog-wide service relevance and continuity

Apply to the whole addressable catalog, not only fitness. The initial catalog audit should group existing items into practical families such as financial and insurance, housing and utilities, family and education, health and pets, shopping and delivery, subscriptions and media, fitness and recreation, travel and mobility, professional/business, and digital identity. For each catalog item, add or curate only the metadata needed to determine relevance and next action:

- **Household fit:** which declared profile facts matter (children/age bands, pets, owner/renter, vehicle, work/business, retirement, and explicitly selected services).
- **Market fit:** whether the provider operates at origin/destination and its verified service footprint.
- **Audience/cost context:** optional coarse tier or user-facing price context only when supported by a reliable, current source; do not infer the user's own income.
- **Move behavior:** update address, transfer, cancel/re-enroll, verify portability, or no address action.
- **Evidence and confidence:** user-confirmed, provider/catalog verified, area-level contextual signal, or an unverified candidate.

Do not force every service into an income tier. Some needs are driven by household structure or geography (e.g. pediatric care, school records, homeowners insurance, utilities); others by stated behavior (e.g. subscriptions, retail accounts); some may correlate with market income or affordability. Encode the relevant evidence per item instead of applying one demographic rule to all services.

For services the user has explicitly selected, show:

- **What to do:** update address, transfer, cancel/re-enroll, verify portability, or no address action.
- **Destination fit:** confirmed nearby options, no options found, or availability not checked.
- **Why shown:** e.g. “You selected Life Time; check membership options near your new ZIP.”
- **Confidence/source:** provider-confirmed, catalog-maintained, or map search; never present a map-search miss as proof the service is unavailable.

For services the user has not selected, generate **candidates to confirm**, not asserted enrollments. Rank using a transparent combination of household fit, destination availability, origin-to-destination change, similarity to the user's confirmed service pattern, and any validated service-specific prevalence evidence. If no prevalence evidence exists for a service, do not present demographic correlation as a learned probability; label it as a regional/household-fit suggestion.

Add catalog metadata incrementally; possible concepts include `moveAction`, `availabilitySearchTerms`/`provider`, `portabilityConfidence`, household fit tags, audience/price context, and evidence source. Avoid adding a second flag registry. Existing `CatalogItem` records and task generation remain the source for address-update tasks.

Use fitness as one validation category, alongside at least one family-driven category and one income-sensitive/financial category. Include Life Time, Orangetheory, 24 Hour Fitness, Planet Fitness, Equinox, LA Fitness, family services, and representative insurance/financial products already in the catalog. Verify Orangetheory's flag/catalog coverage as part of implementation; current code search did not find it represented as a `LifestyleFlag`.

Use the current destination coordinate/neighborhood where available, then the ZIP centroid fallback. MapKit local search already exists for geofences and can support an initial, clearly labeled nearby-location check. Do not persist or transmit a precise device location for this feature. Make provider availability refreshable and expose the check date. A failed search means “couldn’t verify,” not “not available.”

### 2. Move snapshot, not a neighborhood verdict

For US origin/destination areas, introduce a separate comparison model that can eventually report a small set of measures such as:

- Median household income and household-size/family-size distribution.
- Housing costs (rent and home values shown separately).
- Optional household-relevant factors later, such as commute mode, transit access, or family services.

For the first usable release, compare only measures with validated, comparable data. Show source, vintage/period, area (e.g. census tract), and a plain-language limitation. Do not say the customer is above/below the local average. Avoid converting unlike measures into one “upgrade” score.

The Census ACS API and ACS 5-year data are candidate sources for tract/block-group social, economic, housing, and demographic estimates. ACS small-area data are multi-year estimates with uncertainty; carry margins of error where available and suppress or qualify noisy comparisons. Resolve a user-entered location to its area geography using a supported geocoder. Canadian postal codes need a separate, validated data plan; do not silently map Canadian moves to US fallback statistics.

**Data reality:** Census data can describe the market (income distribution, household size, housing, etc.); it does not say how many households in a tract have a Life Time membership, use a particular insurer, or subscribe to a streaming service. Catalog-wide service likelihoods therefore need service-specific prevalence evidence from a suitable licensed/partner dataset or consented product feedback. Until that exists, combine area context with stated household needs, selected services, and verified provider availability as an explainable relevance ranking—not a statistical claim that a family is enrolled.

### 3. Explainable recommendation rules

Keep the first version rule-based and catalog-wide. Build on existing lifestyle flags and destination archetypes, and add explicit rules/metadata for service availability, portability, and household fit. Possible outputs:

- “You selected X; check whether your membership transfers.”
- “We found X locations within your chosen radius of the destination.”
- “We couldn't confirm X near the destination; verify with the provider.”
- “Housing costs are higher/lower in this area estimate,” with the measure and time period stated.
- “Families with a similar household profile often check X when moving here”—only if supported by a suitable, documented service-specific dataset; otherwise use “This may be relevant based on your answers and destination.”

Do not say a service is likely enrolled unless the customer selected it. Do not use neighborhood income as a substitute for a user's income, affordability, race, or family characteristics. Make every suggested action dismissible/correctable and avoid automatically adding speculative tasks.

## Recommended customer journey

Keep the existing fast intake and three-screen interview. Add context where it improves relevance, not a long demographic questionnaire.

1. **Move locations:** retain current date, destination, and optional origin flow. Explain that origin unlocks a before/after comparison. Prefer the neighborhood coordinate already selected; if absent, use the postal area and label the coarser geography. Never require background/live location for market comparison. Offer “skip origin” without blocking the checklist.
2. **Household basics:** retain kids/pets/ownership and child count. Consider an optional household-size selector (adults + children or a simple size band) only if catalog rules demonstrably use it. Do not ask annual income in the MVP. Age bands for children should be optional and only added if they unlock specific catalog items (e.g. school/childcare address changes).
3. **Confirmed services:** keep current selectable chips, but make clear that selected means “we use this; add its move task.” Use progressive disclosure and search in the long-tail catalog rather than showing 100+ items at first run.
4. **Candidate review:** on the existing optional-extras screen, add a small “Worth checking for your household” section with at most a few candidates from varied catalog categories. Each card states the evidence (“based on your answers,” “available near destination,” or “area-level pattern”), has a short reason, and offers **Add**, **Not relevant**, and **Not sure**. “Add” is the only path that creates a checklist task. Keep “see more” in Add More Services.
5. **Dashboard follow-through:** separate confirmed checklist tasks from unconfirmed discovery suggestions. Show service continuity for confirmed items and candidates for review in a secondary surface; don't insert inferred items into the urgency/progress count. Provide a “why am I seeing this?” detail and a correction/feedback action.
6. **Edit/recompute:** when origin, destination, or household answers change, recompute contextual candidates without resetting completed tasks. Preserve user dismissals and explicit answers. Give dismissals an expiry/revisit behavior only if the move/location materially changes.

This flow uses location as a useful determinant while keeping the first-run experience short and the checklist trustworthy. Area context should increase/decrease candidate priority; it should not mark a service as enrolled.

## Recommended backend design

### Separate facts, context, candidates, and tasks

- **Household facts:** existing self-reported flags, financial institutions, child count, pets/species, housing status. Store source and update time where practical.
- **Move geography:** entered origin/destination codes, selected neighborhood coordinates, resolved Census geography IDs, country, geography level, and resolution confidence. Prefer a tract when accurately resolved; fall back transparently to ZIP/ZCTA, city, or state. Never treat the `"US"` unknown-state sentinel as a real geography.
- **Regional context snapshot:** estimates keyed by geographic ID, source, vintage/period, and uncertainty metadata. Fetch/cache or bundle it separately from user facts; do not write aggregate statistics into `LifestyleProfile` as though they describe that household.
- **Catalog evidence:** per-service household-fit tags, operating footprint, move action/portability, price/audience data source and date, and the type of evidence supporting a candidate. Keep the flat catalog declarative as project guidance requires.
- **Candidate result:** service ID, rank/evidence tier, reason codes, destination availability state, and user response (`add`, `notRelevant`, `notSure`, unseen). Candidates are not `ChecklistTask`s until the user confirms.
- **Checklist tasks:** continue to be generated by `ChecklistGenerator` from confirmed flags and institutions only.

### Ranking strategy

Use a staged, explainable ranker rather than starting with a black-box model:

1. Apply hard relevance rules from household needs and catalog requirements/exclusions.
2. Check destination availability/portability where a credible provider source exists. Treat search failure or missing footprint data as **unknown**, not unavailable.
3. Use origin-to-destination changes and regional context to raise/lower discovery priority. Signals can include local income distribution, family/household-size mix, housing tenure/cost, and relevant regional archetype—but keep each signal explicit.
4. Use confirmed-service combinations as weak personalization evidence only after enough opt-in, service-level outcomes exist. A single brand choice should not be treated as proof of income or another service enrollment.
5. Initially return reasoned rank bands such as **Strong match**, **Worth checking**, and **Low confidence**, not numeric probabilities. Calibrated probabilities require a representative labeled dataset, holdout evaluation, and monitoring for drift.

Track candidate impressions and responses as structured, service-level outcomes if learning is later pursued. The current synthetic/noisy embedding queue is not a substitute for this event schema; any transmission would require a separate product/privacy decision, updated disclosure, and explicit data-governance design.

### Location-data options and tradeoffs

- **Public baseline:** ACS 5-year data supports income, housing, and household composition at tract/block-group scales in the US. It is an aggregate market prior, not service enrollment. Fetch the same vintage for both locations, retain margins of error, and avoid strong claims when uncertainty overlaps. The ACS B11016 table includes household type by household size. [ACS API coverage](https://api.census.gov/data/2024/acs/acs5.html), [B11016 table](https://data.census.gov/table/ACSDT5Y2023.B11016).
- **Geography resolution:** a ZIP-to-state bucket is insufficient for “this neighborhood” predictions. Census geocoding can resolve provided locations to tract identifiers, but the request fields, retention, and consent implications should be reviewed. A selected neighborhood coordinate can improve the match; a ZIP centroid can land in the wrong tract, so return an explicit coarse/low-confidence status.
- **Service prevalence:** ACS does not measure adoption of the app's 100+ brands. Commercial geodemographic products such as Experian Mosaic, ArcGIS Tapestry, and Claritas PRIZM describe modeled market segments and lifestyle/behavior attributes, but require procurement and license/privacy review. They may provide market propensity, not verified enrollment of this user. [Experian Mosaic](https://www.experian.com/marketing/consumer-view/data/mosaic), [ArcGIS Tapestry](https://www.esri.com/en-us/arcgis/products/arcgis-data/explore/tapestry-data), [Claritas PRIZM](https://claritas.com/prizm-premier/).
- **Availability:** current MapKit local search supports destination POI discovery, but provider existence/branch search is not equivalent to service eligibility, coverage, or membership portability. Use provider-specific verified footprints for high-confidence claims where available; otherwise show the check as provisional.
- **On-device constraint:** a nationwide tract cache can be large and needs a refresh mechanism. A small on-demand request avoids shipping a huge dataset but sends a geography lookup to an external source. Choose deliberately and disclose the destination/origin fields involved; keep household flags and service answers out of those requests.

The Census Bureau cautions that conclusions about individuals cannot be directly inferred from aggregate census geographies, and that geographic aggregation choices can change results. Treat neighborhood context as context, not as a personal profile. [Census working paper on contextual fallacy](https://www.census.gov/library/working-papers/2018/adrm/ces-wp-18-11.html).

### Candidate signal and evidence lifecycle

Keep these evidence levels distinct in storage and in the interface:

| Evidence | Example | Safe product use |
|---|---|---|
| Customer confirmed | User selects a bank, daycare, subscription, or gym | Create the relevant task; high confidence the service applies |
| Customer household fact | User reports children, household size, pets, homeowner/renter | Apply explicit catalog rules and offer household-relevant checks |
| Provider/official geography | Provider footprint, utility territory, state eligibility | Determine whether a move action or availability check is relevant |
| Area-level market prior | Tract household-size mix, income distribution, or licensed segment | Adjust the rank of optional candidates; disclose as an area pattern, not user fact |
| Learned co-selection | Opt-in aggregate patterns among prior users | Adjust candidate ordering only after enough valid labels and evaluation |

For service-level prevalence, a positive user selection is a label; an unselected chip is **not** automatically a negative label because users may have skipped it. Capture explicit `yes / no / unsure` responses if those will later train/evaluate a model. Do not turn non-response into evidence that a household does not use a service.

Do not define a catalog-wide propensity from a single `incomeTier` tag alone. A bank/investment service, a streaming subscription, a school, a utility, and a membership have different enrollment mechanisms. Data-model per-service evidence and validate each category; use a weak cross-service prior only where outcomes show that it helps.

### Evaluation gates before making stronger claims

- Start with **reasoned ranks**, not percent likelihood. Run the ranker on reviewed example households/moves before adding candidates to onboarding.
- Measure precision among the top few suggestions and explicit “not relevant” rates by service family, evidence type, and geography resolution. Keep “unsure” separate from “no.”
- If a probabilistic model is eventually trained, require a holdout set, calibration evaluation, subgroup/error review, drift monitoring, and a minimum evidence threshold per service. Show a probability only if it is empirically calibrated and useful to customers.
- Do not optimize only for acceptance taps: confirmation requires friction, and dismissal may reflect poor UX. Also measure correction and completed move actions.
- Any cross-install learning requires a redesigned privacy model. Current `SignalEmitter` noise is a deterministic random-looking feature vector plus Laplace noise, not differential privacy with a documented epsilon budget, and its event payload lacks service-specific yes/no labels. Treat it as non-training telemetry until reviewed.

## Follow-on scope

1. **Catalog and model coverage:** progressively add service action/portability, provider availability, household fit, and evidence metadata across all catalog groups. Distinguish service footprint from legal/state eligibility and from address-change requirements.
2. **Household fit controls:** optional, user-selected priorities (e.g. housing budget, commute mode, transit, proximity to childcare or recreation). Ask only when it changes a recommendation; allow “skip.”
3. **Better location comparisons:** support neighborhood/tract estimates, ACS uncertainty, source vintage refreshes, metropolitan housing-cost context, and Canada only after source parity is established.
4. **Opt-in learning:** only after enough consented accept/reject and correction events exist, a validated service-level outcome dataset is available, data governance is defined, and a useful evaluation set exists. Current local `PendingSignal` records do not train a model and are not transmitted.

## Out of scope for the initial release

- Predicting personal income, creditworthiness, wealth, race, or socioeconomic class from location or service choices.
- Ranking neighborhoods as objectively “better” or “worse.”
- Automatically enrolling users, changing accounts, or declaring a provider unavailable based on a failed search.
- Training a predictive model from the current synthetic/noisy signal representation or claiming calibrated service-enrollment probabilities without outcome data.
- US/Canada comparisons until definitions, vintages, currencies, and geographies are made comparable.

## Data and privacy requirements

- Treat origin/destination area statistics as aggregate context, never as attributes of the user.
- Prefer postal code/neighborhood selection already supplied by the user; request precise location only for a separate feature that needs it.
- Do not send the user's full selected-service list, family profile, or precise coordinates to a demographic or recommendation vendor. If a map/place provider is used for a specific availability lookup, send only the necessary provider/category query and destination search area, disclose that lookup, and review the vendor's retention and use terms.
- Document provider/map requests and their fields; cache only what provider terms permit.
- For every statistic, retain source, geography, vintage, estimate, and uncertainty metadata.
- Provide a way to correct service selections and report inaccurate local results.

## Success measures

- Service suggestions across catalog categories accepted, dismissed, corrected, and later completed.
- Candidate precision by service/category and by evidence source, so demographic context does not crowd out higher-confidence household facts.
- Rate of false/unhelpful provider matches, measured through user feedback.
- Checklist additions that users confirm as genuinely relevant.
- Comparison-card comprehension: users understand the statistic describes the area, not their household.
- No increase in onboarding abandonment from additional questions; keep new household questions optional.

## Delivery sequence

1. Audit the full service catalog and map each item to household-fit signals, geography/availability, portability, and evidence quality; define the minimal shared metadata schema.
2. Pilot the ranking flow across representative categories (fitness, family/education, and financial/insurance) while keeping all additions user-confirmed.
3. Add a user-visible move snapshot only after selecting and validating tract-level measures, geocoding behavior, and uncertainty presentation.
4. Expand catalog coverage and tune ranking from opt-in corrections and measured relevance; do not expand model claims faster than the evidence.

## Source references

- Census ACS table/geography availability: <https://www.census.gov/programs-surveys/acs/data/data-tables.html>
- Census ACS API datasets: <https://www.census.gov/data/developers/data-sets.html>
- Census Geocoder API: <https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html>
- CFPB research on demographic proxies (relevant caution for individual profiling): <https://www.consumerfinance.gov/data-research/research-reports/using-publicly-available-information-to-proxy-for-unidentified-race-and-ethnicity/>
- Google Places API reference (alternative provider/place search source; assess cost and data-use terms before adoption): <https://developers.google.com/maps/documentation/places/web-service/reference/rest>
