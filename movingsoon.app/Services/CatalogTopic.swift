import Foundation

/// Browsing topics are independent of saved review families and household facts.
/// They help people recall services; they do not imply that someone uses a brand.
enum CatalogTopic: String, CaseIterable, Identifiable {
    case groceries, meals, wine, coffee, clothing, beauty, boxes, refills, reading
    case shopping, digital, homeServices, storage, deliveryAccess, personalCare, community, pets, care, vehicleCare
    case general
    var id: String { rawValue }

    var title: String {
        switch self {
        case .groceries: return "Groceries & food delivery"
        case .meals: return "Meal kits & prepared meals"
        case .wine: return "Wine & beverage clubs"
        case .coffee: return "Coffee & tea subscriptions"
        case .clothing: return "Clothing, styling & rentals"
        case .beauty: return "Beauty & grooming deliveries"
        case .boxes: return "Gift, hobby & activity boxes"
        case .refills: return "Household refills & autoship"
        case .reading: return "Books, newspapers & magazines"
        case .shopping: return "Shopping & retail memberships"
        case .digital: return "Streaming, apps & digital accounts"
        case .homeServices: return "Home maintenance & recurring visits"
        case .storage: return "Storage & rental accounts"
        case .deliveryAccess: return "Packages, mailboxes & delivery access"
        case .personalCare: return "Salon, spa & personal-care plans"
        case .community: return "Local clubs, culture & recreation"
        case .pets: return "Pet care, supplies & memberships"
        case .care: return "Care services & medical deliveries"
        case .vehicleCare: return "Car care, charging & parking plans"
        case .general: return "Other services"
        }
    }

    var prompt: String {
        switch self {
        case .groceries: return "Which apps, stores or local farms bring food to your door?"
        case .meals: return "Is a meal box or prepared-food delivery already on its way?"
        case .wine: return "Do you belong to a winery, wine, beer or spirits club?"
        case .coffee: return "Does your coffee or tea arrive automatically?"
        case .clothing: return "Any styling boxes, clothing rentals or returns still outstanding?"
        case .beauty: return "Do skincare, makeup, razors or hair products arrive on repeat?"
        case .boxes: return "Any monthly boxes or gifts that someone else ordered for you?"
        case .refills: return "What gets replenished before you notice it has run out?"
        case .reading: return "What do you receive in the mail or borrow locally?"
        case .shopping: return "Which shops keep a saved shipping address or membership profile?"
        case .digital: return "Which accounts save a billing address or household location?"
        case .homeServices: return "Who regularly visits or maintains your current home?"
        case .storage: return "Are you paying for storage, equipment or a rented space?"
        case .deliveryAccess: return "Who needs your new unit number, access instructions or package preferences?"
        case .personalCare: return "Any prepaid visits, treatment packages or local memberships?"
        case .community: return "Which local places do you belong to or visit using a pass?"
        case .pets: return "Who looks after your pets, and what arrives for them?"
        case .care: return "Are care visits, equipment or regular health deliveries tied to this address?"
        case .vehicleCare: return "Any recurring car washes, charging accounts or parking subscriptions?"
        case .general: return "Add the accounts and services that apply to your household."
        }
    }

    var movingTip: String? {
        switch self {
        case .groceries, .meals:
            return "Check the next order as well as your saved address. Confirm delivery coverage, arrival date and instructions for the new home; pause a delivery if you will be between homes."
        case .wine:
            return "Check the next shipment, your club's delivery area and any recipient or signature requirements. Ask the club about a pause or change before an order is processed."
        case .coffee, .beauty, .boxes, .refills:
            return "Review each recurring shipment and its next delivery date. Check gift recipients and separate subscriptions; changing the account address may not change an order already being prepared."
        case .clothing:
            return "Check the next shipment and any returns you still owe. Update the saved address and ask the provider about orders already being prepared or a pause during the move."
        case .reading:
            return "Check delivery and mailing details for each subscription or membership. For a local service, ask about transfer, pause or cancellation."
        case .shopping:
            return "Check saved shipping and billing addresses, membership details and outstanding orders separately. Remove an old default address when you no longer need it."
        case .digital:
            return "Review your billing address and any saved household or home location. Follow the provider's account settings for changes."
        case .homeServices:
            return "Confirm the final visit and any equipment or key return at the old home. Check whether service can transfer, and arrange a new start date only if needed."
        case .storage:
            return "Update contact and billing details. Check notice requirements, access arrangements, automatic payments and any items or equipment that must be returned."
        case .deliveryAccess:
            return "Update your unit number, delivery instructions and package preferences. Remove obsolete access instructions and check any deliveries already in progress."
        case .personalCare, .community:
            return "Update your member record and ask about unused credits, local access, transfer, pause or cancellation before the next renewal."
        case .pets:
            return "Check upcoming deliveries or visits, the address on file and whether the provider serves the new home. Arrange any records transfer directly with the provider."
        case .care:
            return "Contact the provider about address changes and continuity of visits, deliveries or equipment. Confirm the next appointment or shipment before moving."
        case .vehicleCare:
            return "Update your account address and saved home location. Check local access, automatic renewals and whether a location-specific plan needs to transfer or end."
        case .general: return nil
        }
    }

    var searchTerms: String {
        switch self {
        case .groceries: return "grocery groceries supermarket food delivery pickup loyalty rewards farm CSA produce"
        case .meals: return "meal kit prepared meals frozen food foodbox dinner"
        case .wine: return "winery vineyard wineclub beer spirits beverage alcohol membership"
        case .coffee: return "coffee tea roaster beans subscription"
        case .clothing: return "clothes fashion stylist styling clothing rental wardrobe"
        case .beauty: return "beauty skincare skin care makeup cosmetics razor shaving grooming hair"
        case .boxes: return "subscription box monthly gift hobbies craft activity toys"
        case .refills: return "autoship auto ship subscribe save recurring refill replenish household detergent filters"
        case .reading: return "book newspaper magazine print subscription library reading"
        case .shopping: return "retail shopping store membership shipping ecommerce wholesale"
        case .digital: return "streaming music games gaming app digital subscription"
        case .homeServices: return "maintenance cleaning lawn pest pool repair household visits"
        case .storage: return "storage selfstorage locker rental equipment parking"
        case .deliveryAccess: return "parcel package mailbox mail delivery instructions apartment access locker"
        case .personalCare: return "salon spa massage facial haircut wellness beauty membership"
        case .community: return "museum zoo aquarium theater theatre library recreation pool community membership pass"
        case .pets: return "pet dog cat food litter groomer boarding daycare training supplies"
        case .care: return "care caregiver home health medical equipment supplies mobility"
        case .vehicleCare: return "car wash carwash auto detail vehicle EV charging parking garage subscription"
        case .general: return ""
        }
    }

    var isRecurringReview: Bool { self != .general && self != .deliveryAccess }

    static func forID(_ id: String) -> CatalogTopic {
        groups.first { $0.value.contains(id) }?.key ?? .general
    }

    private static let groups: [CatalogTopic: Set<String>] = [
        .groceries: ["publix", "heb", "meijer", "wegmans", "kroger", "safeway", "albertsons", "doordash", "ubereats", "grubhub", "instacart", "amazon_fresh", "pc_optimum", "scene_plus"],
        .meals: ["hellofresh", "blueapron", "mealkit_other"],
        .wine: ["wine_club"], .coffee: ["coffee_subscription"], .clothing: ["clothing_box"],
        .beauty: ["beauty_box", "fabfitfun"],
        .boxes: ["bespoke_post", "kids_activity_box", "kids_crate_box", "snack_box"],
        .refills: ["delivery_autoship_review"],
        .reading: ["book_of_the_month", "nyt_subscription", "wapo_subscription", "wsj_subscription", "local_newspaper", "magazine_subscription", "barnesandnoble"],
        .shopping: ["amazon", "amazon_prime", "costco", "samsclub", "bjs", "target", "walmart", "rei", "bestbuy", "ikea", "wayfair", "triangle_rewards", "tractor_supply_neighbors_club", "bass_pro_cabelas_club"],
        .digital: ["netflix", "hulu", "disneyplus", "hbomax", "appletv", "paramount", "peacock", "spotify", "applemusic", "siriusxm", "youtube_premium", "gaming_subs", "sling", "apple_app_store", "google_play", "patreon_substack", "apple_id_billing", "google_account_billing", "microsoft_account", "playstation_account", "nintendo_account"],
        .homeServices: ["pool_spa_service", "lawn_care_service", "snow_removal_service", "pest_control", "cleaning_service", "window_washing", "septic_service"],
        .community: ["social_club", "religious_institution", "charitable_donations", "political_contributions", "conservation_org_membership", "alumni"],
        .pets: ["vet", "pet_insurance", "pet_insurance_update", "microchip", "chewy", "pet_autoship", "rover", "pet_records_review"],
        .care: ["mail_pharmacy"]
    ]
}

struct CatalogBrowseSection: Identifiable {
    let family: ReviewFamily
    let topic: CatalogTopic
    let items: [CatalogItem]
    var id: String { family.rawValue + ":" + topic.rawValue }
    var title: String { topic == .general ? family.title : topic.title }

    static func sections(for items: [CatalogItem]) -> [Self] {
        ReviewFamily.allCases.flatMap { family in
            CatalogTopic.allCases.compactMap { topic in
                let matches = items.filter { $0.reviewFamily == family && $0.topic == topic }
                return matches.isEmpty ? nil : Self(family: family, topic: topic, items: matches)
            }
        }
    }
}
