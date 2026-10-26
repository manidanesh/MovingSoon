# Paid-release content and geography audit — October 20, 2026

The current action-content source is `Services/CatalogGuidance.swift`. Its 44 important service identities have eligibility, preparation, action steps, suggested timing, source and a review date. Verified official instructions and provider-neutral checklists are explicitly distinguished in `sourceNote`; a review date on a general checklist is not certification that a provider's current account screens or deadlines were checked.

This audit covers USPS; US licence/ID, registration and inspection; voter registration; IRS; SSA; pending US passport applications; Medicare; VA; Canada Post; CRA; Service Canada; Elections Canada; Canadian passport address guidance; electric, gas, water, trash, internet and security accounts; old/new utility dates; landlord forwarding; previous-home policies; school portals; work benefits; recurring deliveries; household/pet records; auto/home/renters/health insurance; veterinary and microchip records; student loans; mortgage and pension administrators; Amazon; Stitch Fix; Instacart; wine clubs; and LA Fitness. Equivalent aliases use their canonical identity.

## Content corrections

- An issued US passport does not require a general address-change filing. The task now refers to a pending application, requires confirmation and explains when it can be removed. Canadian passport address guidance is a separate, optional check; moving does not invalidate the passport.
- SSA explicitly limits the address-update use case to relevant benefit/SSI/Medicare customers. Veteran status, retirement or a postal code does not establish every benefit account. Eligibility-sensitive tasks require review and explicit addition.
- Medicare is distinct from Medicaid. Medicare address changes go through SSA; plans can need separate service-area/enrollment review. A general insurance checklist does not establish coverage or a legal deadline.
- Voter guidance tells the customer to check citizenship, age, residence and the election office's requirements. Election deadlines are not calculated from moving day.
- Licence, registration and inspection actions use a destination lookup of official motor-vehicle agencies, with the USAGov directory as fallback. Commercial dmv.org URLs were removed. Separate Texas/Georgia/Utah registration routing is retained where agencies differ.
- Every timing explanation identifies dates as planning suggestions and directs customers to the agency/provider's actual requirements. There is no maintained nationwide legal-deadline engine.
- Generic provider guidance asks customers to check their own account or agreement. It does not invent authenticated screens, transfer eligibility, cancellation periods, delivery coverage or a particular change cutoff. Local map results remain unconfirmed leads.
- App Store copy now describes optional regional context/provider lookup, removes the unsupported automatic LA Fitness/Xcel coverage example, automatic one-tap completion promise, old postal fee/scam claim and obsolete price-tier label. The $4.99 US target must be set in App Store Connect.

## Primary sources reviewed October 20, 2026

| Official source | Scope used |
|---|---|
| [USPS change-of-address basics](https://faq.usps.com/articles/Knowledge/Change-of-Address-The-Basics) | Identity checks; individual/family/business choices; separate recipients; international process; direct sender updates. No fee is hardcoded. |
| [USAGov motor-vehicle directory](https://www.usa.gov/state-motor-vehicle-services) | Official agency domains by destination; no state-specific deadline is asserted. |
| [Vote.gov registration](https://vote.gov/register) | State/territory update process and election-related deadlines. |
| [IRS address changes](https://www.irs.gov/faqs/irs-procedures/address-changes/address-changes) | Supported personal/business update methods and the limits of relying on postal forwarding. |
| [SSA address-change eligibility](https://www.ssa.gov/faqs/en/questions/KA-01711.html) | Benefits/SSI/Medicare eligibility and method differences. |
| [US passport FAQ](https://travel.state.gov/en/passports/contact-support/faq.html) | Pending-application delivery address versus already-issued passports. |
| [Medicare address changes](https://www.medicare.gov/basics/change-address) and [move-related plan enrollment](https://www.medicare.gov/basics/get-started-with-medicare/get-more-coverage/joining-a-plan/special-enrollment-periods) | SSA address update and separate plan-area review; no computed enrollment window. |
| [VA profile address changes](https://www.va.gov/change-address/) | Shared profile scope and programs with separate records. |
| [Canada Post purchasing](https://www.canadapost-postescanada.ca/cpc/en/support/kb/receiving/forwarding-mail/how-to-purchase-mail-forwarding.page) and [forwarding features](https://www.canadapost-postescanada.ca/cpc/en/support/articles/mail-forwarding/features.page) | Identity, recipients, lead-time checking and service exclusions. |
| [Government of Canada address directory](https://www.canada.ca/en/government/change-address.html) | Separate agency/program updates rather than a universal government address change. |
| [Elections Canada registration](https://www.elections.ca/content.aspx?section=vot&dir=reg&document=index&lang=e) | Eligible electors and registration checking at the current address. |
| [Passport Canada general help](https://www.canada.ca/en/immigration-refugees-citizenship/services/canadian-passports/help-centre/general.html) | Issued-passport address guidance and validity; pending deliveries checked separately. |
| [Federal Student Aid repayment preparation](https://studentaid.gov/articles/6-ways-prepare-repayment-begin-again/) | Update both federal profile and current servicer contact information. |
| [AAHA microchip details](https://www.aaha.org/resources/how-to-update-microchip-details-the-first-step-in-lost-pet-prevention/) | Identify the actual registry and change its record directly, separate from clinic records. |
| [HealthCare.gov moving guidance](https://www.healthcare.gov/reporting-changes/when-you-move/) | Evidence for keeping contact edits distinct from plan coverage; general insurance guidance directs to each actual insurer. |

## Postal-region repair

The old table collapsed Delaware into Pennsylvania, Virginia/Maryland into DC, Georgia into Mississippi, Arkansas into Louisiana, Wyoming into Idaho and Alaska/Hawaii/Pacific postal destinations into Washington/California. The table now uses narrower ranges for all 50 states and DC, handles PR/VI, exact Pacific destinations (AS/GU/MP/PW/FM/MH), military AA/AE/AP ranges, the 005/055/06390 exceptions and Nunavut's X0A/X0B/X0C FSAs. Unassigned prefixes return unknown instead of being absorbed into a neighboring state.

Sources: [IRS current ZIP-region tables](https://www.irs.gov/irm/part3/irm_03-041-267r), [USPS DMM 608 Pacific destinations](https://pe.usps.com/text/dmm300/608.htm), [USPS lowest ZIP](https://facts.usps.com/lowest-zip-code/), [IRS unique office ZIPs](https://www.irs.gov/irm/part1/irm_01-022-003), [New York government Fishers Island address](https://extapps.dec.ny.gov/fs/projects/lswmp/Fisher_Island_LSWMP_2019-2028.2019-08-13.pdf), [Canada Post postal codes](https://origin-www.canadapost.ca/cpc/en/support/articles/addressing-guidelines/postal-codes.page), and [Canada Post territory FSAs](https://origin-www.canadapost.ca/cpc/en/support/articles/delivery-standards/important-definitions.page).

`ZipBucketService.repairRegionBuckets(for:)` repairs a persisted destination bucket without altering task IDs, completion or notes. This is approximate postal-region context, not a licensed address-validation database. ZIP delivery areas can cross jurisdiction boundaries; use the real street address and agency requirements for legal decisions. Unknown/unassigned codes are not certified as real addresses by a format check. Military and freely associated postal destinations have explicit buckets; that does not imply comprehensive moving coverage for them.

## Link maintenance — October 22, 2026

`python3 scripts/check_catalog_links.py` deterministically validates the maintained HTTPS inventory, all 50 DMV state destinations/DC and rejects commercial dmv.org links. `--live-verify` opts into HEAD/GET checks; `--kind` and `--limit` allow targeted review. Permanent missing/bad-request links are failures, while access controls, rate limits and transport errors stay unverified. A live run exits nonzero while any result remains unverified, rather than reporting unavailable checks as passes.

The October 22 full review returned **59 reachable and 11 unverified out of 70 entries, with zero permanent HTTP failures**. The former Hawaii 404 was replaced with the official [Hawaii licensing/county directory](https://hidot.hawaii.gov/driverslicense/) and the replacement is reachable. The remaining blocked/timed-out entries require another access path or manual checking; their official source-review dates are not a claim that every HTTP client could reach them. See the [full result](research/catalog-link-review-2026-10-22.json).

A customer-entered provider name that changes a branded task now uses provider-neutral guidance. It cannot inherit the old brand's default website or verified instructions. A deliberately different customer website remains available, and nickname-only changes keep the real provider identity.

## Remaining release boundary

The remaining catalog has provider-neutral guidance rather than a fully audited per-provider instruction directory. Provincial/cross-border requirements and jurisdiction deadlines are not certified comprehensive. Public support/privacy URLs, production links and on-device behavior must be validated before submission. The historical review below records earlier delivery work and its validation at that time; it is not evidence that every later change has been tested.

---

# Service catalog review and expansion

Reviewed October 7, 2026. This describes local source changes, not an App Store release or phone update.

## What was actually missing

The starting catalog contained 350 definitions. Wine clubs, a grouped Stitch Fix/Trunk Club clothing entry, Instacart and several grocery chains were already present. Their existence in source did not make them easy to find:

1. The interview defined a `subscriptions` chip group but rendered only five other groups. Wine, coffee and clothing-box choices were absent from the actual onboarding screen.
2. Full catalog review put many unrelated services into one Shopping & subscriptions list. Searching looked only at the title and broad review family; a search for “groceries” could miss Instacart, and “stitchfix” did not match “Stitch Fix.”
3. Review recurring accounts used a fixed 25-entry research-pilot list as its entire customer-facing scope. Wine and many other everyday recurring accounts were outside that list.
4. Generic entries combined several providers while linking to only one. A wine-club entry could send a Firstleaf member to Winc; a beauty-box entry sent all providers to IPSY.
5. Many useful service types were absent: clothing rentals, CSA shares, refill subscriptions, personal-care plans, storage, care services, cultural memberships and more.
6. The catalog generally said “update address” without helping the customer distinguish account defaults, orders already processing, returns, service transfer and unused membership credits.

Nordstrom's own filing records the decision to sunset Trunk Club, so it should not be presented as a current provider choice. Historical names are retained only to recognize saved checklist records. [Nordstrom filing](https://www.sec.gov/Archives/edgar/data/72333/000007233322000156/jwn-20220430.htm).

## Scope implemented

**52 new definitions: eight named providers and 44 generic service checks. Total: 402 definitions.** Definitions include aliases and grouped services; this is not a count of unique providers or tasks shown to each customer.

Eight named additions: Stitch Fix, Firstleaf, Shipt, Thrive Market, Misfits Market, ButcherBox, Nuuly and Rent the Runway. They need an explicit provider selection or an Add action. New generic services need an Add action. None is created from income, a ZIP, a broad children/pets answer or a topic selection alone.

| Everyday area | Coverage and changes |
|---|---|
| Groceries | Existing store accounts and delivery apps; added Shipt, Thrive Market, Misfits Market, local grocery delivery, delivery passes, farm/CSA shares and dairy/egg deliveries. |
| Meals | Existing meal kits; added ButcherBox, prepared meals and specialty food deliveries. Guidance checks the next order and whether someone will be home. |
| Wine and beverages | Generic winery/wine-club coverage retained; Firstleaf is separate; added other beverage clubs. Guidance asks the customer to confirm delivery area and shipment requirements with the provider. |
| Coffee and tea | Generic coffee/roaster subscriptions retained with provider-neutral handling; added tea subscriptions. |
| Clothing | Separate Stitch Fix, Nuuly and Rent the Runway entries; generic styling and other rental options. Guidance includes upcoming shipments and outstanding returns. |
| Beauty and grooming | Beauty boxes, FabFitFun and new skincare, hair-product and razor-refill checks. Generic boxes no longer all route to one brand. |
| Household replenishment | Cleaning/paper refills, air/water filters, water delivery, vitamins and contact-lens deliveries. Filter guidance asks whether the product still fits the new home. |
| Children and gifts | Existing learning boxes; added diapers, baby food, crafts/hobbies, flowers and subscriptions gifted to or by the customer. Children's box aliases now share an identity. |
| Reading and culture | Existing publications/books; added library cards, museums, zoos, aquariums, gardens, theater/cinema accounts and season tickets. |
| Local memberships | Added recreation passes, adult classes, salon/barber plans and spa/massage packages; check unused credits and transfer/pause options. |
| Home visits and rentals | Existing cleaning, pest, lawn, pool and other services; added laundry pickup, HVAC maintenance, self-storage and equipment/tool rentals. |
| Pets and care | Existing veterinary, insurance, microchip, food and walking accounts; added grooming, daycare/training, home-care visits, medical deliveries and community meal support. |
| Vehicles | Added car-wash plans, EV charging accounts and monthly parking. Existing registration, insurance, toll and travel accounts remain available. |
| Work and delivery access | Added coworking, professional/union memberships, private/virtual mailboxes and building package lockers. |

## Customer journey

- The existing third interview screen now includes **Wine, Clothing & Monthly Boxes**. Named grocery and clothing choices are available there. No new mandatory interview step was added.
- **Review services** has quick routes for groceries, wine, clothing, meals, refills and community accounts, followed by topic sections within the existing ten review families.
- Nineteen focused browsing topics organize the relevant services; other catalog services retain their family grouping. Topics do not replace saved review-family decisions.
- Search includes topic vocabulary, explicit aliases, case/diacritic normalization and compact forms such as “stitchfix.” A new search clears a topic filter so it searches the full geographically relevant catalog.
- **Review recurring accounts** uses the recurring catalog topics plus the original pilot entries, grouped and searchable. Customers can skip entire sections. Explicit yes/no/unsure answers remain separate from adding a task.
- **What to check for your move** appears in catalog details, and **For this move** appears in task details. Guidance covers deliveries already scheduled, old defaults, return obligations, access details, local coverage and transfers.
- Suggested-service explanations use recall questions for the appropriate topic. Ranking still honors household context, explicit answers, deferred suggestions and reviewed families.

## Existing customer data

- Existing task IDs, completion, notes, snoozes and individual decisions are preserved. The initial catalog expansion added eight provider flags in the existing flag representation. The subsequent account/date delivery adds optional SwiftData fields; existing-store migration still needs a device walkthrough.
- Older grouped titles are recognized by exact aliases. Only their known obsolete links are removed, avoiding a guessed provider destination.
- The two children's-activity-box definitions share a canonical identity for new additions. Existing tasks are not deleted or merged. Older saved answers are copied to the shared identity, keeping the most recent explicit answer.
- Reviewed families remain reviewed. Customers can still search them or reopen review; new catalog content does not silently reset those choices.
- Generic local-provider checks work for US and Canadian moves. The eight new named providers are gated to US move context; that is not proof of coverage at a particular destination. An account from the origin may still need closing when moving across the border.

## Primary-source checks

Provider pages were reviewed on October 7, 2026. They support the specific additions and guidance below; they do not establish authenticated account access or coverage at the customer's address. Brand homepage links are used where a stable account-support route was not established.

| Source | Detail used |
|---|---|
| [Stitch Fix address help](https://support.stitchfix.com/support/solutions/articles/153000250486-how-to-update-your-shipping-address) and [shipping locations](https://support.stitchfix.com/support/solutions/articles/153000250441-where-can-stitch-fix-ship-to-) | Account-info update; family-profile shipping address; support for shipments already labeled/shipped; US shipping context. |
| [Instacart address help](https://www.instacart.com/help/section/3252458959/3043297912) | Saved addresses apply to future orders; active orders need separate handling. |
| [Firstleaf help](https://help.firstleaf.com/hc/en-us) and [membership terms](https://www.firstleaf.com/pages/terms) | Separate address, shipment and membership controls; US membership context. Specific cutoff/legal rules are not hardcoded into this catalog. |
| [Shipt address help](https://help.shipt.com/how-do-i-change-my-address) | Saved address management in the account's Addresses section. |
| [Thrive recurring orders](https://help.thrivemarket.com/hc/en-us/articles/360056187972-Can-I-have-Recurring-orders-sent-to-a-different-address) and [shipping scope](https://help.thrivemarket.com/hc/en-us/articles/360035168471-Can-I-gift-a-membership-to-someone-outside-the-U-S) | Recurring orders use the default shipping address; US shipping context. |
| [Nuuly shipping help](https://www.nuuly.com/rent/help/shipping) | Shipping-address changes, pending orders and returns; US-only shipping. |
| [Rent the Runway](https://www.renttherunway.com/) and [shipping help](https://www.renttherunway.com/help/faq?a=Do-you-ship-internationally-to-PO-Boxes-or-APOFPO-addresses---id--SgsqbivGRCSLsnZ41ICrNQ) | Clothing rental/subscription service and US shipping/return scope. |
| [Misfits Market coverage](https://www.misfitsmarket.com/locations) | Grocery delivery with destination-specific coverage checking. |
| [ButcherBox shipping help](https://support.butcherbox.com/hc/en-us/articles/115015712387-Where-do-you-deliver-to) | Delivery service limited to the contiguous US. |

## Separate accounts and dates — implemented locally October 8

The next two catalog improvements are now implemented:

- Open **Review services → Accounts & dates** beside an added service. Rename the initial task for your first provider, then use **Add another account** for additional memberships. The recurring-account review also opens this screen; task details have **Edit account & reminder dates**.
- Each account has its own task UUID, optional nickname and provider website. Accounts share their catalog identity for discovery but retain independent completion, snooze, mute and removal. Removing the last account records a service dismissal; removing one of several keeps the service confirmed.
- Optional next shipment and renewal dates use a selectable 0, 1, 3, 7, 14 or 30-day lead time. Earlier account deadlines affect the next action, due labels, overdue counts, calendar grouping and location-monitoring priority. Moving-day edits do not shift these dates.
- Local reminders are scheduled for the lead date and event date at 9 a.m., subject to notification permission and task eligibility. Same-day date reminders are batched, with each account included once. Existing critical, snooze and check-in reminders remain separate; the scheduler retains its 60-request limit.
- Completing, muting or removing an account stops its future reminders; snooze defers eligibility. Editing dates rebuilds the schedule. Dates in the past do not create retroactive alerts. Reopen a completed task to resume reminders.
- Names and dates are customer-entered. There is no provider login, order import, automatic renewal rollover or account change. At that delivery, custom provider names did not enable new map matching. The current October 22 implementation also matches explicitly entered provider names; nicknames remain labels and do not identify a place.

Normal catalog Add remains idempotent. **Add another account** is the explicit path to another task, and duplicate names within that service require a distinct nickname. Existing saved task identities are retained before renaming.

## Remaining scope

These additions address this review's highest-value omissions. A full maintained provider directory needs further work:

1. **Provider maintenance:** audit the remaining legacy brand labels and account links, add per-entry source/verification dates and a retirement process. This review did not validate all 402 definitions.
2. **Canadian and regional brand depth:** expand named grocery, delivery, refill and local membership examples using official sources. Generic options are available now; a national catalog does not prove local service availability.
3. **Delivery coverage:** geographic country filtering and nearby map listings do not answer whether groceries, care or meal deliveries serve a particular address. Use provider confirmation until an appropriate coverage integration exists.
4. **Guided recall:** an optional review organized around “what arrives,” “where we belong” and “who visits” could further shorten browsing. Do not infer that a household buys wine, premium clothing or a particular membership from its income area.

## Validation boundary

Static source inventory found 402 distinct literal IDs; `git diff --check` is clean. Simulator compilation for both the catalog expansion and the subsequent account/date delivery is recorded in IMPLEMENTATION_STATUS.md. Automated tests, an interactive screen walkthrough and phone installation have not been performed for these updates. The earlier 240-test result predates these changes.
