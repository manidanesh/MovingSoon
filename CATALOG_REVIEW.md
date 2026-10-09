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
- Names and dates are customer-entered. There is no provider login, order import, automatic renewal rollover or account change. Custom provider names do not enable new map matching; nearby reminders retain the supported catalog/provider matches.

Normal catalog Add remains idempotent. **Add another account** is the explicit path to another task, and duplicate names within that service require a distinct nickname. Existing saved task identities are retained before renaming.

## Remaining scope

These additions address this review's highest-value omissions. A full maintained provider directory needs further work:

1. **Provider maintenance:** audit the remaining legacy brand labels and account links, add per-entry source/verification dates and a retirement process. This review did not validate all 402 definitions.
2. **Canadian and regional brand depth:** expand named grocery, delivery, refill and local membership examples using official sources. Generic options are available now; a national catalog does not prove local service availability.
3. **Delivery coverage:** geographic country filtering and nearby map listings do not answer whether groceries, care or meal deliveries serve a particular address. Use provider confirmation until an appropriate coverage integration exists.
4. **Guided recall:** an optional review organized around “what arrives,” “where we belong” and “who visits” could further shorten browsing. Do not infer that a household buys wine, premium clothing or a particular membership from its income area.

## Validation boundary

Static source inventory found 402 distinct literal IDs; `git diff --check` is clean. Simulator compilation for both the catalog expansion and the subsequent account/date delivery is recorded in IMPLEMENTATION_STATUS.md. Automated tests, an interactive screen walkthrough and phone installation have not been performed for these updates. The earlier 240-test result predates these changes.
