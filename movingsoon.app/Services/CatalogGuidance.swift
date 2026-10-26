import Foundation

/// Reviewed instructions and clearly marked provider-neutral checklists share one UI contract.
/// Planning dates in MovingSoon never replace an agency, insurer or provider deadline.
struct TaskGuidance {
    let eligibility: String
    let preparation: [String]
    let steps: [String]
    let timing: String
    let sourceTitle: String
    let sourceURL: URL?
    let reviewedOn: String
    let sourceNote: String
}

@MainActor
enum CatalogGuidance {
    static let reviewDate = "October 20, 2026"
    static let importantReviewedIDs: Set<String> = [
        "usps", "dmv_license", "dmv_vehicle", "vehicle_inspection", "voter", "irs", "ssa", "passport", "medicare", "va",
        "canada_post", "cra_address", "service_canada", "elections_canada", "passport_canada",
        "electric", "gas", "water", "trash", "internet", "home_security", "old_utilities_final_bill", "new_utilities_start",
        "landlord_forwarding", "previous_home_policy", "school_meal_account", "work_benefits_review", "delivery_autoship_review",
        "household_address_review", "pet_records_review", "auto_insurance", "home_insurance", "renters_insurance", "health_insurance",
        "vet", "microchip", "student_loans", "mortgage", "pension", "amazon", "stitch_fix", "instacart", "wine_club", "lafitness"
    ]

    private static func identity(_ task: ChecklistTask) -> String? {
        task.catalogItemID ?? ItemCatalog.legacyItem(titled: task.accountBaseTitle ?? task.title)?.canonicalID
    }

    /// Dynamic DMV routing never sends the customer to the former commercial dmv.org link.
    /// Customers should verify the actual address's jurisdiction, especially near a border.
    static func actionURL(for task: ChecklistTask, move: Move) -> URL? {
        let item = identity(task).flatMap { ItemCatalog.byID[$0] }
        if task.category != .government, !ServiceAccountService.usesCatalogProvider(task, item: item) {
            // A new provider owns its own website; never revive the old brand's link.
            return ServiceAccountService.providerWebsite(for: task, item: item)
        }
        if let id = identity(task), ["dmv_license", "dmv_vehicle", "vehicle_inspection"].contains(id) {
            return motorVehicleURL(for: move.destinationStateBucket, registration: id != "dmv_license")
        }
        if let id = identity(task), let official = officialURLs[id] { return URL(string: official) }
        return task.deepLinkURL
    }

    static func guidance(for task: ChecklistTask, move: Move) -> TaskGuidance {
        let id = identity(task) ?? ""
        if task.category != .government,
           !ServiceAccountService.usesCatalogProvider(task, item: ItemCatalog.byID[id]) {
            return providerGuidance(task, move: move, id: "")
        }
        let official = officialURLs[id]
        func reviewed(_ eligibility: String, _ preparation: [String], _ steps: [String], _ timing: String,
                      _ title: String, _ url: String? = nil) -> TaskGuidance {
            TaskGuidance(eligibility: eligibility, preparation: preparation, steps: steps, timing: timing,
                sourceTitle: title, sourceURL: url.flatMap(URL.init(string:)) ?? official.flatMap(URL.init(string:)),
                reviewedOn: reviewDate, sourceNote: "Official guidance reviewed; open the source for current requirements.")
        }
        switch id {
        case "usps":
            return reviewed("For mail sent to your previous US address. Choose the move type and names that match the people actually moving.",
                ["Complete old and new mailing addresses, including unit numbers", "Forwarding start date and acceptable identity documents"],
                ["Use USPS directly to choose permanent or temporary forwarding and the correct individual, family or business option.",
                 "People with different last names, or people staying behind, can require separate individual requests.",
                 "Save USPS confirmation details and update senders separately. International moves require the Post Office process before leaving."],
                "Arrange forwarding before the move. Check the official service's current fees and start-date rules; the app's date is a planning reminder.", "USPS change-of-address basics")
        case "dmv_license", "dmv_vehicle", "vehicle_inspection":
            return reviewed("Check if you hold a licence/ID, own a registered vehicle, or need a destination inspection. A ZIP code does not establish eligibility or an exact jurisdiction.",
                ["Current licence/ID or vehicle details", "Actual new address and the destination agency's required proof and appointments"],
                ["Open the destination's official motor-vehicle agency and choose moving/address change, new resident, or registration as appropriate.",
                 "Check licence, title/registration, insurance and inspection separately; one update may not change the others.",
                 "Follow the agency's own effective dates, documentation and deadlines, and retain its confirmation."],
                "Check the agency before moving. The suggested checklist date is not a legal filing deadline.",
                "USAGov official motor-vehicle agency directory", "https://www.usa.gov/state-motor-vehicle-services")
        case "voter":
            return reviewed("Only if you are eligible to register and vote in the relevant jurisdiction. Review citizenship, age and residence requirements with the election office.",
                ["New residential address", "Identification and registration details requested by your election office"],
                ["Choose your state or territory on Vote.gov to update or register at the new address.", "Check the election office's registration deadline and verify the resulting registration."],
                "Review before the next registration deadline; it is tied to elections and local rules, not the moving date.", "Vote.gov registration and address changes", "https://vote.gov/register")
        case "irs":
            return reviewed("For your personal US tax address; a business may need a separate Form 8822-B update.",
                ["Old/new mailing addresses and the official form's identity details", "Separate details for spouses if your addresses now differ"],
                ["Open IRS address-change options and select the current form, signed statement or other supported method.", "Use the mailing instructions on the current IRS form and keep a copy. Postal forwarding alone should not be relied on to update tax records."],
                "Notify the IRS after your address changes. Allow for processing and check the official instructions for your situation.", "IRS address-change options", "https://www.irs.gov/faqs/irs-procedures/address-changes/address-changes")
        case "ssa":
            return reviewed("SSA says no address change is needed if you receive neither Social Security benefits, SSI nor Medicare. Add this task only if one applies.",
                ["Your SSA sign-in details or the documents requested by SSA", "New address and effective date"],
                ["Use SSA's contact-information process for your benefit type.", "SSI or other situations may require contacting SSA instead of an online mailing-address edit. Save your confirmation."],
                "Check promptly when your address changes; benefit-specific reporting requirements come from SSA.", "Social Security address-change eligibility", "https://www.ssa.gov/faqs/en/questions/KA-01711.html")
        case "passport":
            return reviewed("Only for a passport application still being processed. A move after receiving your US passport does not require an address update or replacement passport.",
                ["Pending application details", "New mailing address"],
                ["If your application is still in progress, follow the State Department's contact instructions for a changed delivery address.", "If the passport and supporting documents have already arrived, remove this task unless another issue applies."],
                "Contact the agency promptly for an in-progress application; there is no general post-move passport address filing.", "US Department of State passport FAQ")
        case "medicare":
            return reviewed("For people enrolled in Medicare. Medicaid is a separate state program and is not updated by this task.",
                ["SSA/Medicare account details", "New address and any Medicare Advantage or drug-plan information"],
                ["Update the official Medicare address through Social Security, even if you do not receive Social Security payments.", "Contact your plan to check the new service area and any move-related enrollment options; confirm continuity before ending coverage."],
                "Review before moving and check the plan's own enrollment window. The app does not calculate that window.", "Medicare official address-change instructions")
        case "va":
            return reviewed("For benefits or care you actually receive from VA; veteran status alone does not establish every benefit account.",
                ["Verified VA sign-in", "New home and mailing addresses; list of VA programs you use"],
                ["Update home and mailing information in your VA.gov profile.", "Check programs with separate records, including VA home loans, life insurance or CHAMPVA, and contact them directly where required."],
                "Review before the move and confirm each relevant program's requirements.", "VA address-change scope")
        case "canada_post":
            return reviewed("For mail sent to an old Canadian address. Check every recipient's name and whether items you expect can be forwarded.",
                ["Old/new addresses, all recipient names and start date", "Government-issued photo ID and current payment requirements"],
                ["Choose Canada Post's moving or temporary forwarding service and follow online or Post Office identity checks.", "Check the service exclusions and update senders directly, especially for parcels. Keep the receipt to manage the service."],
                "Buy before the required start date and confirm current lead times and pricing with Canada Post.", "Canada Post purchasing and forwarding requirements")
        case "cra_address", "service_canada":
            return reviewed(id == "cra_address" ? "For your CRA tax/benefit records; confirm which personal or business accounts apply." : "For EI, CPP, OAS or other Service Canada programs you actually use.",
                ["Secure account access or the identity details requested by the agency", "New address and effective date; list of programs"],
                ["Use the Government of Canada address-change directory to reach each relevant program's current process.", "Update each agency/program separately and retain confirmation; a change with one government service is not a universal update."],
                "Review promptly when your address changes and follow each program's reporting requirements.", "Government of Canada address-change directory", "https://www.canada.ca/en/government/change-address.html")
        case "elections_canada":
            return reviewed("For Canadian citizens who meet Elections Canada's age and other voter eligibility requirements; a Canadian postal code alone does not establish eligibility.",
                ["Current identity/address evidence requested by Elections Canada"],
                ["Use the official voter-registration service to check your record and update the address.", "Verify your registration at the new address and consult the current election-specific instructions."],
                "Check before an election's registration deadlines; the checklist's date is a suggestion.", "Elections Canada voter registration")
        case "passport_canada":
            return reviewed("For a Canadian passport you already hold or an application in progress. A changed address does not invalidate an issued Canadian passport.",
                ["Your passport or application details", "New address"],
                ["Read Passport Canada's current address guidance for your passport format.", "If you are awaiting delivery, contact the passport program about the application instead of treating an issued-passport note as a delivery change."],
                "Check promptly for a pending delivery; otherwise use the official passport guidance without assuming a replacement is needed.", "Passport Canada address guidance")
        case "student_loans":
            return reviewed("For student loans you actually hold. This source covers US federal loans; private or Canadian loans use their own servicers.",
                ["Current servicer and account sign-in", "New mailing address and contact details"],
                ["Update contact information with each servicer and, for US federal loans, in your StudentAid.gov profile.", "Check the saved details and continue following your payment schedule; the app does not modify loan arrangements."],
                "Review before the next statement or important servicing notice.", "Federal Student Aid contact-information guidance")
        case "microchip":
            return reviewed("For a pet with a registered microchip. Updating a vet's file does not necessarily update the chip registry.",
                ["Microchip number and registry access", "Current phone, email and new address"],
                ["Identify the registry from your pet's records or AAHA's registry lookup tool.", "Update contact information directly with the registry and confirm the saved record."],
                "Review before moving and whenever your contact details change.", "AAHA microchip registry guidance")
        default: return providerGuidance(task, move: move, id: id)
        }
    }

    private static func providerGuidance(_ task: ChecklistTask, move: Move, id: String) -> TaskGuidance {
        let eligibility = task.isUserAdded ? "Your own reminder; adjust it to your circumstances." : "Only if you use this account or are responsible for this service. Confirm local availability and requirements directly."
        var preparation = ["Provider account access or a recent statement", "Complete new address, including unit number, and the date it should take effect"]
        var steps = ["Use your provider's own website, app, statement contact details or support team to request the change.", "Check mailing, billing, delivery and other account records separately, then save the provider's confirmation."]
        var timing = "Planning suggestion: review by the date shown on this task. The provider's actual cutoff or reporting deadline takes precedence."
        switch id {
        case "electric", "gas", "water", "trash", "internet", "home_security", "old_utilities_final_bill", "new_utilities_start":
            preparation += ["Old/new service addresses, access dates and equipment details"]
            steps = ["Confirm who is responsible for each property and whether your provider serves the actual new address.", "Arrange old stop/final billing and new start/transfer separately. Confirm installation, deposits, equipment returns and any gap with the provider.", "Keep both confirmations; a mailing-address edit alone may not transfer service."]
            timing = "Start planning before the move; agree actual stop/start dates with the provider and property owner."
        case "landlord_forwarding":
            steps = ["Give the previous landlord or property manager your forwarding address using the notice method in your lease.", "Ask how to receive final statements or deposit correspondence and retain a dated copy of your message."]
            timing = "Check your lease and local requirements; this is a planning reminder rather than a statement of a deposit or notice deadline."
        case "auto_insurance", "home_insurance", "renters_insurance", "previous_home_policy", "health_insurance", "condo_insurance":
            preparation += ["Policy details and new property/vehicle location or healthcare needs"]
            steps = ["Ask your insurer or agent to review the new address, effective dates and whether coverage can continue there.", "Confirm any policy replacement, local service area, premium change and separate old-home coverage before ending an existing policy.", "Retain the updated policy or written confirmation. A contact-address edit does not establish coverage."]
        case "school_meal_account":
            preparation += ["Each child's school and any separate transport, meal or parent-portal accounts"]
            steps = ["Contact the school or district about the new address, enrollment and transport responsibilities.", "Review meal balances, payments and parent portals separately; confirm required records and keep the result for each child."]
        case "work_benefits_review":
            steps = ["Update your employer's payroll/HR record using its approved process.", "Review benefits, retirement and other administrators separately; ask HR about a jurisdiction change rather than assuming one profile edit updates every account."]
        case "household_address_review":
            steps = ["List the people moving and identify individual, joint and shared accounts.", "Check consent and responsibility with each person, then add separate account reminders where needed. One household task does not submit changes for everyone."]
        case "pet_records_review", "vet":
            preparation += ["Each pet's clinic, medications, registration and insurance details"]
            steps = ["Notify your current veterinary provider and request records or prescription-transfer arrangements if needed.", "Review pet licensing, microchip registry, insurance and deliveries as separate records; confirm any destination requirements with the relevant organization."]
        case "delivery_autoship_review", "amazon", "stitch_fix", "instacart", "wine_club":
            preparation += ["Next shipment/order, return obligations and delivery instructions"]
            steps = ["Review the saved shipping and billing addresses in each account.", "Check orders already being prepared separately; ask the provider to redirect, pause or change a shipment if the account edit does not cover it.", "Verify destination delivery coverage, return arrangements and the next order's address before marking done."]
            timing = "Review before the provider's next processing cutoff; a shipment date alone is not a guaranteed edit deadline."
        case "lafitness":
            steps = ["Ask your membership provider whether your particular plan transfers or allows access at the new location.", "Confirm local access, credits and any notice or cancellation terms. Nearby map listings do not establish membership access."]
        case "mortgage", "pension":
            steps = ["Update contact information with the current servicer or administrator using its approved account process.", "Check each loan, plan or statement address separately and retain confirmation; continue existing payment or contribution arrangements."]
        default:
            if let tip = ItemCatalog.byID[id]?.moveGuidance { steps.insert(tip, at: 1) }
        }
        return TaskGuidance(eligibility: eligibility, preparation: preparation, steps: steps, timing: timing,
            sourceTitle: "Your provider's current instructions", sourceURL: ServiceAccountService.providerWebsite(for: task),
            reviewedOn: reviewDate,
            sourceNote: "Provider-neutral checklist reviewed on this date. Account screens, eligibility and deadlines must be confirmed with your provider; no provider-specific process is certified here.")
    }

    private static let officialURLs: [String: String] = [
        "usps": "https://faq.usps.com/articles/Knowledge/Change-of-Address-The-Basics",
        "irs": "https://www.irs.gov/faqs/irs-procedures/address-changes/address-changes",
        "ssa": "https://www.ssa.gov/faqs/en/questions/KA-01711.html",
        "passport": "https://travel.state.gov/en/passports/contact-support/faq.html",
        "medicare": "https://www.medicare.gov/basics/change-address",
        "va": "https://www.va.gov/change-address/",
        "canada_post": "https://www.canadapost-postescanada.ca/cpc/en/support/kb/receiving/forwarding-mail/how-to-purchase-mail-forwarding.page",
        "cra_address": "https://www.canada.ca/en/government/change-address.html",
        "service_canada": "https://www.canada.ca/en/government/change-address.html",
        "elections_canada": "https://www.elections.ca/content.aspx?section=vot&dir=reg&document=index&lang=e",
        "passport_canada": "https://www.canada.ca/en/immigration-refugees-citizenship/services/canadian-passports/help-centre/general.html",
        "student_loans": "https://studentaid.gov/articles/6-ways-prepare-repayment-begin-again/",
        "microchip": "https://www.aaha.org/resources/how-to-update-microchip-details-the-first-step-in-lost-pet-prevention/"
    ]

    /// Official agency domains listed by USAGov, reviewed 2026-10-20.
    /// No state-specific deadline is inferred from this directory.
    static func motorVehicleURL(for region: String, registration: Bool = false) -> URL {
        if registration, region == "TX" { return URL(string: "https://www.txdmv.gov/")! }
        if registration, region == "GA" { return URL(string: "https://dor.georgia.gov/motor-vehicles")! }
        if registration, region == "UT" { return URL(string: "https://dmv.utah.gov/")! }
        return URL(string: motorVehicleAgencies[region] ?? "https://www.usa.gov/state-motor-vehicle-services")!
    }

    private static let motorVehicleAgencies: [String: String] = [
        "AL": "https://www.alea.gov/dps/driver-license", "AK": "https://dmv.alaska.gov/",
        "AZ": "https://azdot.gov/mvd", "AR": "https://www.dfa.arkansas.gov/",
        "CA": "https://www.dmv.ca.gov/", "CO": "https://dmv.colorado.gov/",
        "CT": "https://portal.ct.gov/dmv", "DE": "https://www.dmv.de.gov/", "DC": "https://dmv.dc.gov/",
        "FL": "https://www.flhsmv.gov/", "GA": "https://dds.georgia.gov/", "GU": "https://www.guamtax.com/",
        "HI": "https://hidot.hawaii.gov/driverslicense/", "ID": "https://itd.idaho.gov/itddmv/",
        "IL": "https://www.ilsos.gov/", "IN": "https://www.in.gov/bmv/", "IA": "https://iowadot.gov/mvd",
        "KS": "https://www.ksrevenue.gov/dovindex.html", "KY": "https://drive.ky.gov/", "LA": "https://www.expresslane.org/",
        "ME": "https://www.maine.gov/sos/bmv/", "MD": "https://mva.maryland.gov/",
        "MA": "https://www.mass.gov/orgs/massachusetts-registry-of-motor-vehicles", "MI": "https://www.michigan.gov/sos/",
        "MN": "https://dps.mn.gov/divisions/dvs", "MS": "https://www.dps.ms.gov/", "MO": "https://dor.mo.gov/",
        "MT": "https://mvdmt.gov/", "NE": "https://dmv.nebraska.gov/", "NV": "https://dmv.nv.gov/",
        "NH": "https://www.dmv.nh.gov/", "NJ": "https://www.nj.gov/mvc/", "NM": "https://www.mvd.newmexico.gov/",
        "NY": "https://dmv.ny.gov/", "NC": "https://www.ncdot.gov/dmv/", "ND": "https://www.dot.nd.gov/",
        "OH": "https://www.bmv.ohio.gov/", "OK": "https://service.ok.gov/", "OR": "https://www.oregon.gov/odot/dmv/",
        "PA": "https://www.pa.gov/agencies/dmv.html", "RI": "https://dmv.ri.gov/", "SC": "https://www.scdmvonline.com/",
        "SD": "https://dps.sd.gov/driver-licensing", "TN": "https://www.tn.gov/safety/driver-services.html",
        "TX": "https://www.dps.texas.gov/section/driver-license", "UT": "https://dld.utah.gov/",
        "VT": "https://dmv.vermont.gov/", "VA": "https://www.dmv.virginia.gov/", "WA": "https://dol.wa.gov/",
        "WV": "https://transportation.wv.gov/dmv/", "WI": "https://wisconsindmv.gov/", "WY": "https://www.dot.state.wy.us/"
    ]
}
