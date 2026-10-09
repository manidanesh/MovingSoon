// ItemCatalog.swift — Master catalog of every addressable item (Part 1: Always + Government + Transport + Housing)
import Foundation

enum ItemCatalog {

    // MARK: - All items merged
    static let all: [CatalogItem] = government + transport + housing + financial + allLifestyle + allTravel + allInsurance + allDigital + allCanada + moveTransitions + recurringServices
    static let byID: [String: CatalogItem] = all.reduce(into: [:]) { $0[$1.id] = $1 }
    private static let byTitle: [String: [CatalogItem]] = all.reduce(into: [:]) { index, item in
        for title in Set([item.title] + item.legacyTitles) { index[title, default: []].append(item) }
    }

    static func legacyItem(titled title: String) -> CatalogItem? {
        guard let matches = byTitle[title], Set(matches.map(\.canonicalID)).count == 1 else { return nil }
        return matches.first
    }

    static let moveTransitions: [CatalogItem] = [
        CatalogItem(id: "old_utilities_final_bill", title: "Confirm old utility stop dates & final bills", emoji: "📮",
                    category: .utilities, priority: .high, tMinusDays: -7, reviewFamily: .home,
                    discoveryContext: .transition, requiresConfirmation: true, moveAction: .closeOldService),
        CatalogItem(id: "new_utilities_start", title: "Confirm new utility start dates", emoji: "💡",
                    category: .utilities, priority: .critical, tMinusDays: -14, reviewFamily: .home,
                    discoveryContext: .transition, requiresConfirmation: true, moveAction: .startNewService),
        CatalogItem(id: "landlord_forwarding", title: "Give the previous landlord a forwarding address", emoji: "🔑",
                    category: .utilities, priority: .high, tMinusDays: -7, reviewFamily: .home,
                    discoveryContext: .transition, requiresConfirmation: true, moveAction: .closeOldService),
        CatalogItem(id: "school_meal_account", title: "School meal, transport & parent portal accounts", emoji: "🎒",
                    category: .education, priority: .high, tMinusDays: -7, reviewFamily: .family,
                    discoveryContext: .children, requiresConfirmation: true),
        CatalogItem(id: "delivery_autoship_review", title: "Recurring deliveries & saved shipping addresses", emoji: "📦",
                    category: .subscriptions, priority: .high, tMinusDays: -7, reviewFamily: .shopping,
                    requiresConfirmation: true),
        CatalogItem(id: "work_benefits_review", title: "Work benefits & retirement account addresses", emoji: "💼",
                    category: .employer, priority: .high, tMinusDays: -7, reviewFamily: .work,
                    discoveryContext: .work, requiresConfirmation: true),
        CatalogItem(id: "household_address_review", title: "Check each person's accounts & shared deliveries", emoji: "🏠",
                    category: .other, priority: .high, tMinusDays: -7, reviewFamily: .home,
                    requiresConfirmation: true, moveAction: .reviewRequirements),
        CatalogItem(id: "pet_records_review", title: "Pet records, registrations & recurring deliveries", emoji: "🐾",
                    category: .healthcare, priority: .high, tMinusDays: -7, reviewFamily: .healthPets,
                    discoveryContext: .pets, requiresConfirmation: true, moveAction: .reviewRequirements),
        CatalogItem(id: "previous_home_policy", title: "Previous home insurance — review address & coverage", emoji: "🛡️",
                    category: .insurance, priority: .high, tMinusDays: -14, reviewFamily: .insurance,
                    discoveryContext: .transition, requiresConfirmation: true, moveAction: .reviewTransfer)
    ]

    /// The catalog item gated by exactly this one flag, if any — used to get a
    /// title/emoji for a MoveImpactEngine suggestion without depending on the
    /// interview screens' UI-only chip registry (LifestyleViewModel.extraChips).
    static func item(for flag: LifestyleFlag) -> CatalogItem? {
        all.first { $0.requires == [flag] }
    }

    /// Service brands that must be explicitly selected in addition to the broad
    /// household gate. A family answer can surface these choices, never enroll them.
    static func confirmationFlag(for item: CatalogItem) -> LifestyleFlag? {
        familyServiceConfirmationFlags[item.id]
    }

    private static let familyServiceConfirmationFlags: [String: LifestyleFlag] = [
        "stitch_fix": .usesStitchFix, "firstleaf": .usesFirstleaf,
        "shipt": .usesShipt, "thrive_market": .usesThriveMarket,
        "misfits_market": .usesMisfitsMarket, "butcherbox": .usesButcherBox,
        "nuuly": .usesNuuly, "rent_the_runway": .usesRentTheRunway,
        "kids_kumon": .usesKumon, "kids_mathnasium": .usesMathnasium,
        "kids_sylvan": .usesSylvanLearning, "kids_eye_level": .usesEyeLevelLearning,
        "kids_huntington": .usesHuntingtonLearning, "kids_tutoring": .usesTutoringCenter,
        "kids_gymnastics": .usesGymnasticsClub, "kids_gymnastics_usa": .usesUSAGymnasticsClub,
        "kids_gym_little": .usesLittleGym, "kids_swimming": .usesSwimSchool,
        "kids_safesplash": .usesSafeSplash, "kids_martial_arts": .usesMartialArtsStudio,
        "kids_dance": .usesDanceStudio, "kids_cheer": .usesCheerAcademy,
        "kids_soccer": .usesKidsSoccer, "kids_baseball": .usesLittleLeague,
        "kids_basketball": .usesYouthBasketball, "kids_tennis": .usesKidsTennis,
        "kids_hockey": .usesYouthHockey, "kids_i9_sports": .usesI9Sports,
        "kids_rock_climbing": .usesKidsClimbing, "kids_yoga": .usesKidsYoga,
        "kids_music": .usesKidsMusicLessons, "kids_school_of_rock": .usesSchoolOfRock,
        "kids_piano": .usesKidsPianoLessons, "kids_theater": .usesKidsTheater,
        "kids_choir": .usesKidsChoir, "kids_art": .usesKidsArtClass,
        "kids_coding": .usesKidsCoding, "kids_robotics": .usesKidsRobotics, "kids_science": .usesKidsScienceClass,
        "kids_chess": .usesKidsChessClub, "kids_childcare": .usesDaycare,
        "kids_camp": .usesSummerCamp, "kids_scouting": .usesScouting,
        "chewy": .usesChewy, "rover": .usesRover,
    ]

    // MARK: - 🏛️ GOVERNMENT (always shown)
    static let government: [CatalogItem] = [
        CatalogItem(id: "usps", title: "USPS Mail Forwarding", emoji: "📬",
                    category: .postal, priority: .critical, tMinusDays: -30,
                    deepLinkURL: URL(string: "https://moversguide.usps.com"),
                    brandColorHex: "#004B87", isHeroItem: true, excludes: [.isCanadian], alwaysInclude: true, poiCategory: .postOffice,
                    placeSearchName: "USPS post office", placeNameAliases: ["USPS", "United States Postal Service", "US Post Office"], reviewFamily: .identity),
        // t+7, not pre-move: most states require proof of the new address (a lease,
        // utility bill) to re-register at all, which you don't have until you've moved in.
        CatalogItem(id: "dmv_license", title: "Driver's License / State ID", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://dmv.org"),
                    brandColorHex: "#7D3C98", excludes: [.isCanadian], alwaysInclude: true, poiCategory: .dmv, reviewFamily: .identity),
        CatalogItem(id: "voter", title: "Voter Registration", emoji: "🗳️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://vote.gov"),
                    brandColorHex: "#1A5276", excludes: [.isCanadian], alwaysInclude: true, reviewFamily: .identity),
        CatalogItem(id: "irs", title: "IRS Address (Form 8822)", emoji: "🏛️",
                    category: .government, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.irs.gov/forms-pubs/about-form-8822"),
                    brandColorHex: "#1B4F72", excludes: [.isCanadian], alwaysInclude: true, reviewFamily: .identity),
        CatalogItem(id: "ssa", title: "Social Security Administration", emoji: "🛡️",
                    category: .government, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.ssa.gov"),
                    brandColorHex: "#154360", excludes: [.isCanadian], alwaysInclude: true, reviewFamily: .identity),
        CatalogItem(id: "dmv_vehicle", title: "Vehicle Registration (DMV)", emoji: "🚗",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://dmv.org"),
                    brandColorHex: "#7D3C98", requiresAny: [.hasCar, .hasMotorcycle, .hasMultipleCars], excludes: [.isCanadian], poiCategory: .dmv, reviewFamily: .identity),
        CatalogItem(id: "passport", title: "US Passport (address on file)", emoji: "🛂",
                    category: .government, priority: .low, tMinusDays: 30,
                    deepLinkURL: URL(string: "https://travel.state.gov"),
                    brandColorHex: "#1A5276", excludes: [.isCanadian], alwaysInclude: true, reviewFamily: .identity),
        CatalogItem(id: "medicare", title: "Medicare / Medicaid", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.medicare.gov"),
                    brandColorHex: "#1A237E", requiresAny: [.hasMedicare, .isRetired], excludes: [.isCanadian], reviewFamily: .identity),
        CatalogItem(id: "va", title: "VA Benefits", emoji: "🎖️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.va.gov"),
                    brandColorHex: "#003087", requires: [.isVeteran], excludes: [.isCanadian], reviewFamily: .identity),
        CatalogItem(id: "prof_license", title: "Professional License (state board)", emoji: "📋",
                    category: .legal, priority: .high, tMinusDays: -14,
                    brandColorHex: "#8E44AD", requires: [.hasProfessionalLicenses], reviewFamily: .identity),
        CatalogItem(id: "county_assessor", title: "County Tax Assessor — Homestead Exemption", emoji: "🏛️",
                    category: .government, priority: .high, tMinusDays: 14,
                    brandColorHex: "#1A5276", requires: [.isOwning], excludes: [.isCanadian], reviewFamily: .identity),
        CatalogItem(id: "tsa_precheck", title: "TSA PreCheck / Global Entry / CLEAR", emoji: "✈️",
                    category: .government, priority: .high, tMinusDays: -7,
                    brandColorHex: "#004B87", requires: [.hasTSAPreCheck], excludes: [.isCanadian], reviewFamily: .identity),
    ]

    // MARK: - 🚗 TRANSPORT
    static let transport: [CatalogItem] = [
        CatalogItem(id: "uber_address", title: "Update Uber Home Address", emoji: "🚕",
                    category: .other, priority: .medium, tMinusDays: 1,
                    deepLinkURL: URL(string: "https://www.uber.com"),
                    brandColorHex: "#141414", requiresAny: [.usesRideShare], reviewFamily: .travel, discoveryContext: .vehicle, requiresConfirmation: true),
        CatalogItem(id: "lyft_address", title: "Update Lyft Home Address", emoji: "🚕",
                    category: .other, priority: .medium, tMinusDays: 1,
                    deepLinkURL: URL(string: "https://www.lyft.com"),
                    brandColorHex: "#FF00BF", requiresAny: [.usesRideShare], reviewFamily: .travel, discoveryContext: .vehicle, requiresConfirmation: true),
        CatalogItem(id: "toll_ezpass", title: "Toll Transponder (E-ZPass / SunPass / FasTrak)", emoji: "🛣️",
                    category: .other, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.e-zpassiag.com"),
                    brandColorHex: "#1B4F72", requires: [.hasTollRoads], reviewFamily: .travel, discoveryContext: .vehicle),
        CatalogItem(id: "aaa", title: "AAA Membership Address", emoji: "🔧",
                    category: .other, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.aaa.com"),
                    brandColorHex: "#003087", requiresAny: [.hasCar, .hasMotorcycle], reviewFamily: .travel, discoveryContext: .vehicle, requiresConfirmation: true),
        CatalogItem(id: "tesla", title: "Tesla Account / MyEV Address", emoji: "⚡",
                    category: .other, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.tesla.com"),
                    brandColorHex: "#CC0000", requires: [.hasElectricVehicle], reviewFamily: .travel, discoveryContext: .vehicle, requiresConfirmation: true),
        CatalogItem(id: "google_maps", title: "Google Maps Home Address", emoji: "🗺️",
                    category: .other, priority: .low, tMinusDays: 1,
                    deepLinkURL: URL(string: "https://maps.google.com"),
                    brandColorHex: "#4285F4", alwaysInclude: true, reviewFamily: .travel, discoveryContext: .vehicle, requiresConfirmation: true),
        CatalogItem(id: "apple_maps", title: "Apple Maps Home Address", emoji: "🍎",
                    category: .other, priority: .low, tMinusDays: 1,
                    brandColorHex: "#555555", alwaysInclude: true, reviewFamily: .travel, discoveryContext: .vehicle, requiresConfirmation: true),
        CatalogItem(id: "airline_loyalty", title: "Airline Loyalty (Delta, United, etc.)", emoji: "✈️",
                    category: .subscriptions, priority: .low, tMinusDays: 14,
                    brandColorHex: "#003087", requires: [.hasAirlineLoyalty], reviewFamily: .travel, discoveryContext: .vehicle),
        CatalogItem(id: "vehicle_warranty", title: "Vehicle Extended Warranty", emoji: "🚘",
                    category: .insurance, priority: .medium, tMinusDays: 7,
                    brandColorHex: "#E74C3C", requires: [.hasVehicleWarranty], reviewFamily: .travel, discoveryContext: .vehicle),
        CatalogItem(id: "auto_service_center", title: "Find a New Mechanic / Service Center", emoji: "🔧",
                    category: .other, priority: .medium, tMinusDays: 14,
                    brandColorHex: "#5D6D7E", requiresAny: [.hasCar, .hasElectricVehicle, .hasMultipleCars],
                    poiCategory: .autoRepair, reviewFamily: .travel, discoveryContext: .vehicle),
        CatalogItem(id: "vehicle_inspection", title: "State Safety / Emissions Inspection", emoji: "🔍",
                    category: .government, priority: .high, tMinusDays: -14,
                    brandColorHex: "#7D3C98", requiresAny: [.hasCar, .hasElectricVehicle, .hasMultipleCars],
                    excludes: [.isCanadian], poiCategory: .dmv, reviewFamily: .travel, discoveryContext: .vehicle),
    ]

    // MARK: - 🏠 HOUSING / UTILITIES
    static let housing: [CatalogItem] = [
        CatalogItem(id: "electric", title: "Electric / Power Company", emoji: "💡",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    brandColorHex: "#F5A623", alwaysInclude: true, reviewFamily: .home, discoveryContext: .housing, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "gas", title: "Natural Gas Provider", emoji: "🔥",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    brandColorHex: "#E67E22", alwaysInclude: true, reviewFamily: .home, discoveryContext: .housing, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "water", title: "Water / Sewer Service", emoji: "💧",
                    category: .utilities, priority: .high, tMinusDays: -14,
                    brandColorHex: "#1ABC9C", alwaysInclude: true, reviewFamily: .home, discoveryContext: .housing, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "trash", title: "Trash & Recycling", emoji: "♻️",
                    category: .utilities, priority: .medium, tMinusDays: -7,
                    brandColorHex: "#27AE60", alwaysInclude: true, reviewFamily: .home, discoveryContext: .housing, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "internet", title: "Internet Provider", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    brandColorHex: "#2E86C1", alwaysInclude: true, reviewFamily: .home, discoveryContext: .housing, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "home_security", title: "Home Security System", emoji: "🔒",
                    category: .utilities, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.ring.com"),
                    brandColorHex: "#1C2833", requires: [.hasHomeSecurity], reviewFamily: .home, discoveryContext: .housing, moveAction: .reviewTransfer),
        CatalogItem(id: "hoa", title: "HOA Account & Address", emoji: "🏘️",
                    category: .other, priority: .high, tMinusDays: -14,
                    brandColorHex: "#626567", requires: [.hasHOA], reviewFamily: .home, discoveryContext: .housing),
        CatalogItem(id: "del_webb_search", title: "Find a Del Webb / Sun City Community Near You", emoji: "🏡",
                    category: .other, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.delwebb.com/find-your-del-webb"),
                    brandColorHex: "#003DA5", requires: [.livesInDelWebbCommunity], reviewFamily: .home, discoveryContext: .housing),
        CatalogItem(id: "solar", title: "Solar Panel Provider", emoji: "☀️",
                    category: .utilities, priority: .high, tMinusDays: -14,
                    brandColorHex: "#F39C12", requires: [.hasSolar], reviewFamily: .home, discoveryContext: .housing, moveAction: .reviewTransfer),
        CatalogItem(id: "parking_permit", title: "Parking Authorities & Residential Permits", emoji: "🅿️",
                    category: .other, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#C0392B", requires: [.needsParkingPermit], reviewFamily: .home, discoveryContext: .housing),
        CatalogItem(id: "home_warranty", title: "Appliance & Home Warranties", emoji: "🛠️",
                    category: .insurance, priority: .medium, tMinusDays: 7,
                    brandColorHex: "#34495E", requires: [.hasHomeWarranties], reviewFamily: .home, discoveryContext: .housing),
        CatalogItem(id: "furniture_warranty", title: "Furniture Protection Plans", emoji: "🛋️",
                    category: .insurance, priority: .low, tMinusDays: 14,
                    brandColorHex: "#8E44AD", requires: [.hasHomeWarranties], reviewFamily: .home, discoveryContext: .housing),
        CatalogItem(id: "inform_neighbors", title: "Introduce & Share Info with Neighbors", emoji: "👋",
                    category: .other, priority: .low, tMinusDays: 7,
                    brandColorHex: "#27AE60", requires: [.livesInHouseOrTownhouse], reviewFamily: .home, discoveryContext: .housing),
    ]

    // MARK: - 💳 FINANCIAL (always shown — institution-specific tasks added separately)
    static let financial: [CatalogItem] = [
        CatalogItem(id: "paypal", title: "PayPal Address", emoji: "💸",
                    category: .financial, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.paypal.com"),
                    brandColorHex: "#003087", alwaysInclude: true, reviewFamily: .money, requiresConfirmation: true),
        CatalogItem(id: "venmo", title: "Venmo Address", emoji: "💸",
                    category: .financial, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.venmo.com"),
                    brandColorHex: "#3D95CE", alwaysInclude: true, reviewFamily: .money, requiresConfirmation: true),
        CatalogItem(id: "cashapp", title: "Cash App Address", emoji: "💵",
                    category: .financial, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://cash.app"),
                    brandColorHex: "#00D632", alwaysInclude: true, reviewFamily: .money, requiresConfirmation: true),
        CatalogItem(id: "student_loans", title: "Student Loan Servicer", emoji: "🎓",
                    category: .education, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://studentaid.gov"),
                    brandColorHex: "#1A5276", requires: [.hasStudentLoans], reviewFamily: .money),
        CatalogItem(id: "mortgage", title: "Mortgage Servicer", emoji: "🏡",
                    category: .financial, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#C0392B", requires: [.hasMortgage], reviewFamily: .money),
        CatalogItem(id: "financial_advisor", title: "Financial Advisor / CPA", emoji: "📊",
                    category: .financial, priority: .medium, tMinusDays: 7,
                    brandColorHex: "#27AE60", requires: [.hasFinancialAdvisor], reviewFamily: .money),
        CatalogItem(id: "crypto_exchange", title: "Hardware Wallets & Crypto Exchanges (Coinbase, etc.)", emoji: "🪙",
                    category: .financial, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#F39C12", requires: [.holdsCrypto], reviewFamily: .money),
        CatalogItem(id: "pension", title: "Pension Administrators & 401k/IRA", emoji: "🏦",
                    category: .financial, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#1F618D", requires: [.hasPension], reviewFamily: .money),
    ]
}
