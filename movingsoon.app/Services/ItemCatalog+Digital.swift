// ItemCatalog+Digital.swift — App Stores, Subscription Boxes, News/Magazines, Smart Home, Estate & Digital Identity
import Foundation

extension ItemCatalog {

    static var allDigital: [CatalogItem] {
        appStores + subscriptionBoxes + newsMagazines + smartHome + homeServices + estatePlanning + digitalIdentity + communityFaith
    }

    // MARK: - 📱 App Stores & Digital Ecosystems

    static let appStores: [CatalogItem] = [
        CatalogItem(id: "apple_id_billing", title: "Apple ID / App Store Billing Address", emoji: "🍎",
                    category: .digital, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://appleid.apple.com/"),
                    brandColorHex: "#555555",
                    requiresAny: [.usesAppleAppStore, .usesApplePay, .usesAppleTVPlus, .usesAppleMusic]),
        CatalogItem(id: "google_account_billing", title: "Google Account / Play Store Billing", emoji: "🤖",
                    category: .digital, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://myaccount.google.com/payments-and-subscriptions"),
                    brandColorHex: "#4285F4",
                    requiresAny: [.usesGooglePlay, .usesGooglePay]),
        CatalogItem(id: "microsoft_account", title: "Microsoft Account / Xbox Billing Address", emoji: "🪟",
                    category: .digital, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://account.microsoft.com/billing/"),
                    brandColorHex: "#00A4EF",
                    requires: [.usesGamingSubs]),
        CatalogItem(id: "playstation_account", title: "PlayStation Network Billing Address", emoji: "🎮",
                    category: .digital, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.playstation.com/en-us/playstation-network/"),
                    brandColorHex: "#003087",
                    requires: [.usesGamingSubs]),
        CatalogItem(id: "nintendo_account", title: "Nintendo Account Billing Address", emoji: "🎮",
                    category: .digital, priority: .low, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://accounts.nintendo.com/"),
                    brandColorHex: "#E4000F",
                    requires: [.usesGamingSubs]),
    ]

    // MARK: - 📦 Subscription Boxes & Physical Clubs

    static let subscriptionBoxes: [CatalogItem] = [
        CatalogItem(id: "beauty_box", title: "Beauty Box Subscription (Birchbox / IPSY / Allure)", emoji: "💄",
                    category: .subscriptions, priority: .high, tMinusDays: -3,
                    deepLinkURL: URL(string: "https://www.ipsy.com/profile"),
                    brandColorHex: "#E91E8C",
                    requires: [.usesBeautyBox]),
        CatalogItem(id: "fabfitfun", title: "FabFitFun Shipping Address", emoji: "📦",
                    category: .subscriptions, priority: .high, tMinusDays: -3,
                    deepLinkURL: URL(string: "https://fabfitfun.com/account/"),
                    brandColorHex: "#FF6B6B",
                    requires: [.usesFabFitFun]),
        CatalogItem(id: "bespoke_post", title: "Bespoke Post Shipping Address", emoji: "📦",
                    category: .subscriptions, priority: .high, tMinusDays: -3,
                    deepLinkURL: URL(string: "https://bespokepost.com/account"),
                    brandColorHex: "#2C3E50",
                    requires: [.usesBespokePost]),
        CatalogItem(id: "wine_club", title: "Wine Club Delivery Address (Winc / Firstleaf)", emoji: "🍷",
                    category: .subscriptions, priority: .high, tMinusDays: -3,
                    deepLinkURL: URL(string: "https://www.winc.com/account"),
                    brandColorHex: "#722F37",
                    requires: [.usesWineClub]),
        CatalogItem(id: "coffee_subscription", title: "Coffee Subscription Address (Trade / Peet's)", emoji: "☕",
                    category: .subscriptions, priority: .high, tMinusDays: -3,
                    deepLinkURL: URL(string: "https://www.drinktrade.com/account"),
                    brandColorHex: "#4A2C2A",
                    requires: [.usesCoffeeSubscription]),
        CatalogItem(id: "kids_activity_box", title: "Kids Activity Box (KiwiCo / Little Passports)", emoji: "🧸",
                    category: .subscriptions, priority: .high, tMinusDays: -3,
                    deepLinkURL: URL(string: "https://www.kiwico.com/account"),
                    brandColorHex: "#FF6B35",
                    requires: [.usesKidsCrateBox]),
        CatalogItem(id: "book_of_the_month", title: "Book of the Month Shipping Address", emoji: "📚",
                    category: .subscriptions, priority: .high, tMinusDays: -3,
                    deepLinkURL: URL(string: "https://www.bookofthemonth.com/account"),
                    brandColorHex: "#E74C3C",
                    requires: [.usesBookOfTheMonth]),
        CatalogItem(id: "snack_box", title: "Snack Box Subscription (Graze / Snack Crate)", emoji: "🍿",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.graze.com/us/account"),
                    brandColorHex: "#27AE60",
                    requires: [.usesSnackBox]),
        CatalogItem(id: "clothing_box", title: "Clothing Subscription (Stitch Fix / Trunk Club)", emoji: "👗",
                    category: .subscriptions, priority: .high, tMinusDays: -3,
                    deepLinkURL: URL(string: "https://www.stitchfix.com/account"),
                    brandColorHex: "#4ECDC4",
                    requires: [.usesClothingBox]),
    ]

    // MARK: - 📰 News & Magazines

    static let newsMagazines: [CatalogItem] = [
        CatalogItem(id: "nyt_subscription", title: "New York Times Subscription Address", emoji: "📰",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://myaccount.nytimes.com/"),
                    brandColorHex: "#000000",
                    requires: [.usesNewYorkTimes]),
        CatalogItem(id: "wapo_subscription", title: "Washington Post Subscription Address", emoji: "📰",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://account.washingtonpost.com/"),
                    brandColorHex: "#1A1A1A",
                    requires: [.usesWashingtonPost]),
        CatalogItem(id: "wsj_subscription", title: "Wall Street Journal Subscription Address", emoji: "📰",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://customercenter.wsj.com/"),
                    brandColorHex: "#003DA5",
                    requires: [.usesWallStreetJournal]),
        CatalogItem(id: "local_newspaper", title: "Local Newspaper Subscription Address", emoji: "📰",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    brandColorHex: "#626567",
                    requires: [.usesLocalNewspaper]),
        CatalogItem(id: "magazine_subscription", title: "Magazine Subscriptions (Vogue / Wired / GQ)", emoji: "📖",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    brandColorHex: "#8E44AD",
                    requires: [.usesMagazineSubscription]),
    ]

    // MARK: - 🏠 Smart Home & Security

    static let smartHome: [CatalogItem] = [
        CatalogItem(id: "nest_ecobee", title: "Smart Thermostat App Address (Nest / Ecobee)", emoji: "🌡️",
                    category: .utilities, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://home.nest.com/"),
                    brandColorHex: "#00A59B",
                    requires: [.hasSmartThermostat]),
        CatalogItem(id: "smart_locks", title: "Smart Lock System — Update Account Address", emoji: "🔐",
                    category: .utilities, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.august.com/"),
                    brandColorHex: "#2C3E50",
                    requires: [.hasSmartLocks]),
        CatalogItem(id: "video_doorbell", title: "Video Doorbell Account (Ring / Arlo)", emoji: "🔔",
                    category: .utilities, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://account.ring.com/"),
                    brandColorHex: "#1C2833",
                    requires: [.hasVideoDoorbells]),
        CatalogItem(id: "pool_spa_service", title: "Pool / Spa Maintenance Service", emoji: "🏊",
                    category: .utilities, priority: .medium, tMinusDays: -7,
                    brandColorHex: "#1ABC9C",
                    requires: [.hasPoolSpa]),
    ]

    // MARK: - 🛺 Home Services (Physical Recurring)

    static let homeServices: [CatalogItem] = [
        CatalogItem(id: "lawn_care_service", title: "Lawn Care / Landscaping Service", emoji: "🌿",
                    category: .utilities, priority: .medium, tMinusDays: -7,
                    brandColorHex: "#27AE60",
                    requires: [.hasLawnCareService]),
        CatalogItem(id: "snow_removal_service", title: "Snow Removal Service", emoji: "❄️",
                    category: .utilities, priority: .medium, tMinusDays: -7,
                    brandColorHex: "#AED6F1",
                    requires: [.hasSnowRemovalService]),
        CatalogItem(id: "pest_control", title: "Pest Control Service", emoji: "🐜",
                    category: .utilities, priority: .medium, tMinusDays: -7,
                    brandColorHex: "#E67E22",
                    requires: [.hasPestControlService]),
        CatalogItem(id: "cleaning_service", title: "House Cleaning Service", emoji: "🧹",
                    category: .utilities, priority: .medium, tMinusDays: -7,
                    brandColorHex: "#5D6D7E",
                    requires: [.hasCleaningService]),
        CatalogItem(id: "window_washing", title: "Window Washing Service", emoji: "🪟",
                    category: .utilities, priority: .low, tMinusDays: 7,
                    brandColorHex: "#85C1E9",
                    requires: [.hasWindowWashingService]),
        CatalogItem(id: "septic_service", title: "Septic Tank / Well Service Provider", emoji: "💧",
                    category: .utilities, priority: .high, tMinusDays: -14,
                    brandColorHex: "#1B4F72",
                    requiresAny: [.hasSepticTank, .hasWell]),
    ]

    // MARK: - 📜 Estate & Legal Planning

    static let estatePlanning: [CatalogItem] = [
        CatalogItem(id: "will_update", title: "Will & Testament — Review for New State Laws", emoji: "📜",
                    category: .estate, priority: .high, tMinusDays: 14,
                    brandColorHex: "#2C3E50",
                    requires: [.hasWill]),
        CatalogItem(id: "living_trust", title: "Living Trust — Retitle Property into Trust", emoji: "📜",
                    category: .estate, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#1B4F72",
                    requires: [.hasTrust]),
        CatalogItem(id: "power_of_attorney", title: "Power of Attorney — Update Address on Record", emoji: "✍️",
                    category: .estate, priority: .high, tMinusDays: 14,
                    brandColorHex: "#7D3C98",
                    requires: [.hasPowerOfAttorney]),
        CatalogItem(id: "healthcare_directive", title: "Healthcare Directive / Living Will", emoji: "🏥",
                    category: .estate, priority: .high, tMinusDays: 14,
                    brandColorHex: "#C0392B",
                    requires: [.hasHealthcareDirective]),
        CatalogItem(id: "beneficiary_review", title: "Beneficiary Designations — Life Insurance & Retirement", emoji: "🎯",
                    category: .estate, priority: .critical, tMinusDays: -7,
                    brandColorHex: "#E74C3C",
                    requiresAny: [.hasLifeInsurance, .hasInvestmentAccounts, .hasPension]),
        CatalogItem(id: "safe_deposit_box", title: "Safe Deposit Box — Update Bank Branch Address", emoji: "🗄️",
                    category: .estate, priority: .medium, tMinusDays: 7,
                    brandColorHex: "#212F3D",
                    requires: [.hasSafeDepositBox]),
    ]

    // MARK: - 🌐 Digital Identity

    static let digitalIdentity: [CatalogItem] = [
        CatalogItem(id: "google_maps_home", title: "Google Maps — Update Home & Work Address", emoji: "🗺️",
                    category: .digital, priority: .low, tMinusDays: 1,
                    deepLinkURL: URL(string: "https://maps.google.com"),
                    brandColorHex: "#4285F4", alwaysInclude: true),
        CatalogItem(id: "linkedin_location", title: "LinkedIn — Update Profile Location", emoji: "🔗",
                    category: .digital, priority: .low, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.linkedin.com/in/"),
                    brandColorHex: "#0077B5", alwaysInclude: true),
        CatalogItem(id: "google_business_profile", title: "Google Business Profile — Update Address", emoji: "🏢",
                    category: .digital, priority: .critical, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://business.google.com/"),
                    brandColorHex: "#4285F4",
                    requires: [.hasGoogleBusinessProfile]),
        CatalogItem(id: "personal_website", title: "Personal / Business Website — Update Address", emoji: "🌐",
                    category: .digital, priority: .medium, tMinusDays: 0,
                    brandColorHex: "#2E86C1",
                    requires: [.hasPersonalWebsite]),
        CatalogItem(id: "domain_registrar", title: "Domain Registrar WHOIS Address (GoDaddy / Namecheap)", emoji: "🖥️",
                    category: .digital, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://account.godaddy.com/"),
                    brandColorHex: "#1BBB77",
                    requires: [.usesDomainRegistrar]),
        CatalogItem(id: "password_manager", title: "Password Manager — Update Saved Address (1Password / LastPass)", emoji: "🔑",
                    category: .digital, priority: .low, tMinusDays: 1,
                    deepLinkURL: URL(string: "https://1password.com/"),
                    brandColorHex: "#1A6FD8",
                    requires: [.usesPasswordManager]),
    ]

    // MARK: - 🌿 Community, Faith & Philanthropy

    static let communityFaith: [CatalogItem] = [
        CatalogItem(id: "religious_institution", title: "Religious Institution / Church — Update Directory", emoji: "⛪",
                    category: .other, priority: .low, tMinusDays: 14,
                    brandColorHex: "#6C5CE7",
                    requires: [.attendsReligiousInstitution]),
        CatalogItem(id: "social_club", title: "Social / Country Club — Update Member Address", emoji: "🎭",
                    category: .other, priority: .low, tMinusDays: 14,
                    brandColorHex: "#2C3E50",
                    requires: [.belongsToSocialClub]),
        CatalogItem(id: "charitable_donations", title: "Charitable Donations — Update Donor Address for Tax Receipts", emoji: "💝",
                    category: .other, priority: .medium, tMinusDays: 7,
                    brandColorHex: "#E74C3C",
                    requires: [.donatesCharitably]),
        CatalogItem(id: "political_contributions", title: "Political Contribution Records — Update Address", emoji: "🗳️",
                    category: .government, priority: .medium, tMinusDays: 7,
                    brandColorHex: "#1A5276",
                    requires: [.hasPoliticalContributions]),
    ]
}


