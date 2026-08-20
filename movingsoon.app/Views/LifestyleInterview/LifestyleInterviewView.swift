// LifestyleInterviewView.swift — Simplified 3-screen lifestyle interview
import SwiftUI
import SwiftData

// MARK: - ViewModel

@Observable
final class LifestyleViewModel {
    var currentScreen: Int = 0
    let totalScreens = 3  // 3 simple screens instead of 7

    // Screen 1: Yes/No questions
    var hasKids: Bool = false
    var hasPets: Bool = false
    var ownsHome: Bool = false
    // WS5 — additive refinements, only persisted if the corresponding toggle above is on
    var childCount: Int = 1
    var petSpecies: Set<PetSpecies> = []

    // Screen 2: Financial institutions
    var selectedInstitutions: Set<KnownInstitution> = []

    // Screen 3: Optional extras (expanded inline)
    var expandedCategories: Set<String> = []
    var extraChips: [String: [ChipSection]] = [:]

    init() {
        buildExtraChips()
    }

    func next() {
        if currentScreen < totalScreens - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { currentScreen += 1 }
        }
    }
    func back() {
        if currentScreen > 0 {
            withAnimation(.easeInOut(duration: 0.3)) { currentScreen -= 1 }
        }
    }

    // Core flags from yes/no answers
    var coreFlags: Set<LifestyleFlag> {
        var flags: Set<LifestyleFlag> = []
        if hasKids { flags.insert(.hasChildren) }
        if hasPets { flags.insert(.hasPets) }
        if ownsHome {
            flags.insert(.isOwning)
            flags.insert(.livesInHouseOrTownhouse)
        } else {
            flags.insert(.isRenting)
        }
        return flags
    }

    // All flags including extra selections
    var allActiveFlags: Set<LifestyleFlag> {
        var flags = coreFlags
        for sections in extraChips.values {
            for section in sections {
                flags.formUnion(section.chips.filter { $0.isSelected }.compactMap { $0.flag })
            }
        }
        return flags
    }

    func toggleExtraChip(_ chip: BubbleChip, in category: String) {
        guard let sections = extraChips[category] else { return }
        for (sIdx, section) in sections.enumerated() {
            if let cIdx = section.chips.firstIndex(where: { $0.id == chip.id }) {
                extraChips[category]?[sIdx].chips[cIdx].isSelected.toggle()
                return
            }
        }
    }

    /// Finds the chip backing a given flag, wherever it lives — used by the "Suggested
    /// For This Move" surface so a suggestion toggles the exact same underlying state
    /// as the regular chip grid, never a separate copy that could drift out of sync.
    func chip(for flag: LifestyleFlag) -> BubbleChip? {
        for sections in extraChips.values {
            for section in sections {
                if let chip = section.chips.first(where: { $0.flag == flag }) { return chip }
            }
        }
        return nil
    }

    func isFlagSelected(_ flag: LifestyleFlag) -> Bool {
        chip(for: flag)?.isSelected ?? false
    }

    func toggleFlag(_ flag: LifestyleFlag) {
        for (category, sections) in extraChips {
            for section in sections {
                if let chip = section.chips.first(where: { $0.flag == flag }) {
                    toggleExtraChip(chip, in: category)
                    return
                }
            }
        }
    }

    // MARK: - Optional extra categories (shown on screen 3)

    private func buildExtraChips() {
        // MARK: Original 5 onboarding categories — kept short on purpose (screen 3 of
        // onboarding shares this dict and stays fast); everything added below this point
        // is additional sections/categories that AddMoreServicesView alone lists, so the
        // full long tail is reachable there without bloating first-run onboarding.
        extraChips["shopping"] = [
            ChipSection(title: "Shopping & Delivery", chips: [
                BubbleChip(id: "usesAmazon",     label: "Amazon",       emoji: "📦", flag: .usesAmazon),
                BubbleChip(id: "usesTarget",     label: "Target",       emoji: "🎯", flag: .usesTarget),
                BubbleChip(id: "usesWalmart",    label: "Walmart",      emoji: "🛒", flag: .usesWalmart),
                BubbleChip(id: "usesCostco",     label: "Costco",       emoji: "🏬", flag: .usesCostco),
                BubbleChip(id: "usesDoorDash",   label: "DoorDash",     emoji: "🍕", flag: .usesDoorDash),
                BubbleChip(id: "usesUberEats",   label: "Uber Eats",    emoji: "🍔", flag: .usesUberEats),
                BubbleChip(id: "usesInstacart",  label: "Instacart",    emoji: "🛒", flag: .usesInstacart),
            ]),
            ChipSection(title: "Grocery & Warehouse Stores", chips: [
                BubbleChip(id: "usesSamsClub",   label: "Sam's Club",   emoji: "🏬", flag: .usesSamsClub),
                BubbleChip(id: "usesBJs",        label: "BJ's",         emoji: "🏬", flag: .usesBJs),
                BubbleChip(id: "usesREI",        label: "REI",          emoji: "🏔️", flag: .usesREI),
                BubbleChip(id: "usesBestBuy",    label: "Best Buy",     emoji: "🔌", flag: .usesBestBuy),
                BubbleChip(id: "usesIKEA",       label: "IKEA",         emoji: "🛋️", flag: .usesIKEA),
                BubbleChip(id: "usesWayfair",    label: "Wayfair",      emoji: "🛋️", flag: .usesWayfair),
                BubbleChip(id: "usesPublix",     label: "Publix",       emoji: "🥬", flag: .usesPublix),
                BubbleChip(id: "usesHEB",        label: "H-E-B",        emoji: "🥬", flag: .usesHEB),
                BubbleChip(id: "usesMeijer",     label: "Meijer",       emoji: "🥬", flag: .usesMeijer),
                BubbleChip(id: "usesWegmans",    label: "Wegmans",      emoji: "🥬", flag: .usesWegmans),
                BubbleChip(id: "usesKroger",     label: "Kroger",       emoji: "🥬", flag: .usesKroger),
                BubbleChip(id: "usesSafeway",    label: "Safeway",      emoji: "🥬", flag: .usesSafeway),
                BubbleChip(id: "usesAlbertsons", label: "Albertsons",   emoji: "🥬", flag: .usesAlbertsons),
            ]),
            ChipSection(title: "More Food Delivery & Meal Kits", chips: [
                BubbleChip(id: "usesGrubhub",      label: "Grubhub",         emoji: "🍔", flag: .usesGrubhub),
                BubbleChip(id: "usesAmazonFresh",  label: "Amazon Fresh",    emoji: "🥕", flag: .usesAmazonFresh),
                BubbleChip(id: "usesHelloFresh",   label: "HelloFresh",      emoji: "🍲", flag: .usesHelloFresh),
                BubbleChip(id: "usesBlueApron",    label: "Blue Apron",      emoji: "🍲", flag: .usesBlueApron),
                BubbleChip(id: "usesOtherMealKit", label: "Other Meal Kit",  emoji: "🍲", flag: .usesOtherMealKit),
            ]),
        ]

        extraChips["streaming"] = [
            ChipSection(title: "Streaming & Entertainment", chips: [
                BubbleChip(id: "netflix",     label: "Netflix",     emoji: "🎬", flag: .usesNetflix),
                BubbleChip(id: "hulu",        label: "Hulu",        emoji: "📺", flag: .usesHulu),
                BubbleChip(id: "disney",      label: "Disney+",     emoji: "✨", flag: .usesDisneyPlus),
                BubbleChip(id: "hbo",         label: "Max / HBO",   emoji: "🎭", flag: .usesHBOMax),
                BubbleChip(id: "spotify",     label: "Spotify",     emoji: "🎵", flag: .usesSpotify),
                BubbleChip(id: "gaming",      label: "Xbox / PS",   emoji: "🎮", flag: .usesGamingSubs),
                BubbleChip(id: "xfinity",     label: "Xfinity",     emoji: "📺", flag: .usesXfinity),
                BubbleChip(id: "spectrum",    label: "Spectrum",    emoji: "📺", flag: .usesSpectrum),
            ]),
            ChipSection(title: "More Streaming", chips: [
                BubbleChip(id: "usesAppleTVPlus",    label: "Apple TV+",       emoji: "📺", flag: .usesAppleTVPlus),
                BubbleChip(id: "usesParamountPlus",  label: "Paramount+",      emoji: "📺", flag: .usesParamountPlus),
                BubbleChip(id: "usesPeacock",        label: "Peacock",         emoji: "📺", flag: .usesPeacock),
                BubbleChip(id: "usesAppleMusic",     label: "Apple Music",     emoji: "🎵", flag: .usesAppleMusic),
                BubbleChip(id: "usesSiriusXM",       label: "SiriusXM",        emoji: "📻", flag: .usesSiriusXM),
                BubbleChip(id: "usesYouTubePremium", label: "YouTube Premium", emoji: "▶️", flag: .usesYouTubePremium),
            ]),
            ChipSection(title: "TV & Internet Providers", chips: [
                BubbleChip(id: "usesDirecTV",     label: "DirecTV",       emoji: "📡", flag: .usesDirecTV),
                BubbleChip(id: "usesDish",        label: "Dish",          emoji: "📡", flag: .usesDish),
                BubbleChip(id: "usesVerizonFios", label: "Verizon Fios",  emoji: "📡", flag: .usesVerizonFios),
                BubbleChip(id: "usesATT",         label: "AT&T",          emoji: "📡", flag: .usesATT),
                BubbleChip(id: "usesCox",         label: "Cox",           emoji: "📡", flag: .usesCox),
                BubbleChip(id: "usesOptimum",     label: "Optimum",       emoji: "📡", flag: .usesOptimum),
                BubbleChip(id: "usesSling",       label: "Sling TV",      emoji: "📺", flag: .usesSling),
            ]),
        ]

        extraChips["fitness"] = [
            ChipSection(title: "Fitness & Wellness", chips: [
                BubbleChip(id: "planetfitness", label: "Planet Fitness", emoji: "💪", flag: .usesPlanetFitness),
                BubbleChip(id: "ymca",          label: "YMCA",           emoji: "🏊", flag: .usesYMCA),
                BubbleChip(id: "peloton",       label: "Peloton",        emoji: "🚴", flag: .usesPeloton),
                BubbleChip(id: "localgym",      label: "Local Gym",      emoji: "🏋️", flag: .hasGymMembership),
            ]),
            ChipSection(title: "More Gyms & Studios", chips: [
                BubbleChip(id: "usesEquinox",        label: "Equinox",           emoji: "🏋️", flag: .usesEquinox),
                BubbleChip(id: "usesLAFitness",      label: "LA Fitness",        emoji: "🏋️", flag: .usesLAFitness),
                BubbleChip(id: "usesClassPass",      label: "ClassPass",         emoji: "🧘", flag: .usesClassPass),
                BubbleChip(id: "usesCrossFit",       label: "CrossFit",          emoji: "🏋️", flag: .usesCrossFit),
                BubbleChip(id: "usesOrangeTheory",   label: "Orangetheory",      emoji: "🔥", flag: .usesOrangeTheory),
                BubbleChip(id: "uses24HourFitness",  label: "24 Hour Fitness",   emoji: "💪", flag: .uses24HourFitness),
                BubbleChip(id: "usesLifeTime",       label: "Life Time",         emoji: "🏊", flag: .usesLifeTime),
                BubbleChip(id: "usesJCC",            label: "JCC",               emoji: "🏃", flag: .usesJCC),
                BubbleChip(id: "usesVASA",           label: "VASA Fitness",      emoji: "🏋️", flag: .usesVASA),
                BubbleChip(id: "usesEoS",            label: "EoS Fitness",       emoji: "🏋️", flag: .usesEoS),
                BubbleChip(id: "usesChuze",          label: "Chuze Fitness",     emoji: "🧘", flag: .usesChuze),
                BubbleChip(id: "usesCrunch",         label: "Crunch Fitness",    emoji: "💪", flag: .usesCrunch),
                BubbleChip(id: "usesAnytimeFitness", label: "Anytime Fitness",   emoji: "🏋️", flag: .usesAnytimeFitness),
            ]),
        ]

        extraChips["transport"] = [
            ChipSection(title: "Getting Around", chips: [
                BubbleChip(id: "hasCar",        label: "Car",            emoji: "🚗", flag: .hasCar),
                BubbleChip(id: "hasEV",         label: "Electric Vehicle",emoji: "⚡", flag: .hasElectricVehicle),
                BubbleChip(id: "usesRideShare", label: "Uber / Lyft",    emoji: "🚕", flag: .usesRideShare),
                BubbleChip(id: "hasTollRoads",  label: "Toll Roads",     emoji: "🛣️", flag: .hasTollRoads),
                BubbleChip(id: "hasTSAPre",     label: "TSA PreCheck",   emoji: "🛂", flag: .hasTSAPreCheck),
            ]),
            ChipSection(title: "More Vehicles", chips: [
                BubbleChip(id: "hasMultipleCars", label: "Multiple Cars", emoji: "🚙", flag: .hasMultipleCars),
                BubbleChip(id: "hasMotorcycle",   label: "Motorcycle",    emoji: "🏍️", flag: .hasMotorcycle),
                BubbleChip(id: "hasBike",         label: "E-Bike / Scooter", emoji: "🛴", flag: .hasBike),
            ]),
            ChipSection(title: "Transit Cards", chips: [
                BubbleChip(id: "hasPrestoCard",      label: "Presto (Ontario)",    emoji: "🚇", flag: .hasPrestoCard),
                BubbleChip(id: "hasCompassCard",     label: "Compass (Vancouver)", emoji: "🚇", flag: .hasCompassCard),
                BubbleChip(id: "hasMetroCard",       label: "MetroCard (NYC)",     emoji: "🚇", flag: .hasMetroCard),
                BubbleChip(id: "hasClipperCard",     label: "Clipper (Bay Area)",  emoji: "🚇", flag: .hasClipperCard),
                BubbleChip(id: "hasVentraCard",      label: "Ventra (Chicago)",    emoji: "🚇", flag: .hasVentraCard),
                BubbleChip(id: "hasBreezCard",       label: "Breeze (Atlanta)",    emoji: "🚇", flag: .hasBreezCard),
                BubbleChip(id: "hasOtherTransitCard", label: "Other Transit Card", emoji: "🚇", flag: .hasOtherTransitCard),
            ]),
        ]

        extraChips["life"] = [
            ChipSection(title: "Life & Finance", chips: [
                BubbleChip(id: "hasMortgage",     label: "Mortgage",         emoji: "🏡", flag: .hasMortgage),
                BubbleChip(id: "hasStudentLoans", label: "Student Loans",    emoji: "🎓", flag: .hasStudentLoans),
                BubbleChip(id: "isVeteran",       label: "Veteran",          emoji: "🎖️", flag: .isVeteran),
                BubbleChip(id: "hasMedicare",     label: "Medicare",         emoji: "⚕️", flag: .hasMedicare),
                BubbleChip(id: "isRetired",       label: "Retired",          emoji: "🌅", flag: .isRetired),
                BubbleChip(id: "runsBusiness",    label: "Own a Business",   emoji: "🏢", flag: .runsBusiness),
                BubbleChip(id: "crypto",          label: "Crypto",           emoji: "🪙", flag: .holdsCrypto),
            ]),
            ChipSection(title: "Financial & Professional", chips: [
                BubbleChip(id: "isSelfEmployed",          label: "Self-Employed",       emoji: "💼", flag: .isSelfEmployed),
                BubbleChip(id: "hasProfessionalLicenses", label: "Professional License", emoji: "📋", flag: .hasProfessionalLicenses),
                BubbleChip(id: "hasInvestmentAccounts",   label: "Investment Accounts",  emoji: "📈", flag: .hasInvestmentAccounts),
                BubbleChip(id: "hasLifeInsurance",        label: "Life Insurance",       emoji: "🛡️", flag: .hasLifeInsurance),
                BubbleChip(id: "hasFinancialAdvisor",     label: "Financial Advisor",    emoji: "💼", flag: .hasFinancialAdvisor),
                BubbleChip(id: "hasWill",                 label: "Will",                 emoji: "📜", flag: .hasWill),
            ]),
            ChipSection(title: "Estate Planning", chips: [
                BubbleChip(id: "hasTrust",                label: "Living Trust",         emoji: "🏡", flag: .hasTrust),
                BubbleChip(id: "hasPowerOfAttorney",      label: "Power of Attorney",    emoji: "📜", flag: .hasPowerOfAttorney),
                BubbleChip(id: "hasHealthcareDirective",  label: "Healthcare Directive", emoji: "⚕️", flag: .hasHealthcareDirective),
                BubbleChip(id: "hasSafeDepositBox",       label: "Safe Deposit Box",     emoji: "🔐", flag: .hasSafeDepositBox),
                BubbleChip(id: "hasRentalProperty",       label: "Rental Property",      emoji: "🏘️", flag: .hasRentalProperty),
            ]),
        ]

        // MARK: New categories — only listed in AddMoreServicesView, so onboarding stays fast

        extraChips["household"] = [
            ChipSection(title: "Who's Moving With You", chips: [
                BubbleChip(id: "hasPartner",         label: "Partner / Spouse", emoji: "💑", flag: .hasPartner),
                BubbleChip(id: "hasRoommates",       label: "Roommates",        emoji: "🛋️", flag: .hasRoommates),
                BubbleChip(id: "isMultiGenerational",label: "Multi-Generational Household", emoji: "👨‍👩‍👧‍👦", flag: .isMultiGenerational),
                BubbleChip(id: "workFromHome",       label: "Work From Home",   emoji: "💻", flag: .workFromHome),
            ]),
            ChipSection(title: "Family Accounts", chips: [
                BubbleChip(id: "hasHouseholdHelp",    label: "Household Help",   emoji: "🧹", flag: .hasHouseholdHelp),
                BubbleChip(id: "has529",              label: "529 College Plan", emoji: "🎓", flag: .has529),
                BubbleChip(id: "hasFSA",              label: "FSA",              emoji: "⚕️", flag: .hasFSA),
            ]),
        ]

        extraChips["home"] = [
            ChipSection(title: "Home Features", chips: [
                BubbleChip(id: "hasHOA",               label: "HOA",                   emoji: "🏘️", flag: .hasHOA),
                BubbleChip(id: "hasHomeSecurity",      label: "Home Security System",  emoji: "🔒", flag: .hasHomeSecurity),
                BubbleChip(id: "hasSolar",             label: "Solar Panels",          emoji: "☀️", flag: .hasSolar),
                BubbleChip(id: "livesInDelWebbCommunity", label: "Del Webb / Sun City Community", emoji: "🏡", flag: .livesInDelWebbCommunity),
                BubbleChip(id: "hasHomeWarranties",    label: "Home Warranty",         emoji: "🛠️", flag: .hasHomeWarranties),
                BubbleChip(id: "hasVehicleWarranty",   label: "Vehicle Warranty",      emoji: "🚘", flag: .hasVehicleWarranty),
            ]),
            ChipSection(title: "Smart Home", chips: [
                BubbleChip(id: "hasSmartThermostat", label: "Smart Thermostat", emoji: "🌡️", flag: .hasSmartThermostat),
                BubbleChip(id: "hasSmartLocks",      label: "Smart Locks",      emoji: "🔐", flag: .hasSmartLocks),
                BubbleChip(id: "hasVideoDoorbells",  label: "Video Doorbell",   emoji: "🔔", flag: .hasVideoDoorbells),
                BubbleChip(id: "hasPoolSpa",         label: "Pool / Spa",       emoji: "🏊", flag: .hasPoolSpa),
            ]),
            ChipSection(title: "Recurring Home Services", chips: [
                BubbleChip(id: "hasLawnCareService",       label: "Lawn Care",          emoji: "🌿", flag: .hasLawnCareService),
                BubbleChip(id: "hasPestControlService",    label: "Pest Control",       emoji: "🐜", flag: .hasPestControlService),
                BubbleChip(id: "hasCleaningService",       label: "Cleaning Service",   emoji: "🧹", flag: .hasCleaningService),
                BubbleChip(id: "hasSnowRemovalService",    label: "Snow Removal",       emoji: "❄️", flag: .hasSnowRemovalService),
                BubbleChip(id: "hasWindowWashingService",  label: "Window Washing",     emoji: "🪟", flag: .hasWindowWashingService),
                BubbleChip(id: "hasSepticTank",            label: "Septic Tank",        emoji: "🚰", flag: .hasSepticTank),
                BubbleChip(id: "hasWell",                  label: "Well Water",         emoji: "💧", flag: .hasWell),
            ]),
        ]

        extraChips["insurance"] = [
            ChipSection(title: "Vehicle Insurance", chips: [
                BubbleChip(id: "hasAutoInsurance",       label: "Auto Insurance",       emoji: "🚗", flag: .hasAutoInsurance),
                BubbleChip(id: "hasMotorcycleInsurance", label: "Motorcycle Insurance", emoji: "🏍️", flag: .hasMotorcycleInsurance),
                BubbleChip(id: "hasRVInsurance",         label: "RV Insurance",         emoji: "🚌", flag: .hasRVInsurance),
                BubbleChip(id: "hasBoatInsurance",       label: "Boat Insurance",       emoji: "⛵", flag: .hasBoatInsurance),
            ]),
            ChipSection(title: "Property Insurance", chips: [
                BubbleChip(id: "hasHomeownersInsurance", label: "Homeowner's Insurance", emoji: "🏡", flag: .hasHomeownersInsurance),
                BubbleChip(id: "hasRentersInsurance",    label: "Renter's Insurance",    emoji: "🏠", flag: .hasRentersInsurance),
                BubbleChip(id: "hasLandlordInsurance",   label: "Landlord Insurance",    emoji: "🏘️", flag: .hasLandlordInsurance),
                BubbleChip(id: "hasCondoInsurance",      label: "Condo Insurance",       emoji: "🏢", flag: .hasCondoInsurance),
                BubbleChip(id: "hasFloodInsurance",      label: "Flood Insurance",       emoji: "🌊", flag: .hasFloodInsurance),
                BubbleChip(id: "hasUmbrellaInsurance",   label: "Umbrella Policy",       emoji: "☂️", flag: .hasUmbrellaInsurance),
            ]),
            ChipSection(title: "Specialty Insurance", chips: [
                BubbleChip(id: "hasPetInsurance",        label: "Pet Insurance",           emoji: "🐾", flag: .hasPetInsurance),
                BubbleChip(id: "hasJewelryInsurance",    label: "Jewelry / Collectibles",  emoji: "💎", flag: .hasJewelryInsurance),
                BubbleChip(id: "hasIDTheftProtection",   label: "ID Theft Protection",     emoji: "🔒", flag: .hasIDTheftProtection),
                BubbleChip(id: "hasDisabilityInsurance", label: "Disability Insurance",    emoji: "🛡️", flag: .hasDisabilityInsurance),
            ]),
        ]

        extraChips["travel"] = [
            ChipSection(title: "Travel Habits", chips: [
                BubbleChip(id: "frequentTraveler",   label: "Frequent Traveler",  emoji: "✈️", flag: .frequentTraveler),
                BubbleChip(id: "needsParkingPermit", label: "Airport Parking Permit", emoji: "🅿️", flag: .needsParkingPermit),
                BubbleChip(id: "hasAirlineLoyalty",  label: "Other Airline Loyalty", emoji: "✈️", flag: .hasAirlineLoyalty),
                BubbleChip(id: "hasPension",         label: "Pension",            emoji: "💰", flag: .hasPension),
            ]),
            ChipSection(title: "Airlines", chips: [
                BubbleChip(id: "hasDeltaSkyMiles",        label: "Delta SkyMiles",       emoji: "✈️", flag: .hasDeltaSkyMiles),
                BubbleChip(id: "hasUnitedMileagePlus",    label: "United MileagePlus",   emoji: "✈️", flag: .hasUnitedMileagePlus),
                BubbleChip(id: "hasAmericanAAdvantage",   label: "American AAdvantage",  emoji: "✈️", flag: .hasAmericanAAdvantage),
                BubbleChip(id: "hasSouthwestRapidRewards",label: "Southwest Rapid Rewards", emoji: "✈️", flag: .hasSouthwestRapidRewards),
                BubbleChip(id: "hasAlaskaMileagePlan",    label: "Alaska Mileage Plan",  emoji: "✈️", flag: .hasAlaskaMileagePlan),
                BubbleChip(id: "hasJetBlueTrueBlue",      label: "JetBlue TrueBlue",     emoji: "✈️", flag: .hasJetBlueTrueBlue),
                BubbleChip(id: "hasSpiritFreeSpirit",     label: "Spirit Free Spirit",   emoji: "✈️", flag: .hasSpiritFreeSpirit),
                BubbleChip(id: "hasFrontierMiles",        label: "Frontier Miles",       emoji: "✈️", flag: .hasFrontierMiles),
                BubbleChip(id: "hasAirCanadaAeroplan",    label: "Air Canada Aeroplan",  emoji: "🍁", flag: .hasAirCanadaAeroplan),
                BubbleChip(id: "hasWestJetRewards",       label: "WestJet Rewards",      emoji: "🍁", flag: .hasWestJetRewards),
                BubbleChip(id: "hasPorterVIPorter",       label: "Porter VIPorter",      emoji: "🍁", flag: .hasPorterVIPorter),
                BubbleChip(id: "hasBritishAirwaysExecClub", label: "British Airways Exec Club", emoji: "🌍", flag: .hasBritishAirwaysExecClub),
                BubbleChip(id: "hasFlyingBlue",           label: "Flying Blue (Air France/KLM)", emoji: "🌍", flag: .hasFlyingBlue),
                BubbleChip(id: "hasMilesAndMore",         label: "Miles & More (Lufthansa)", emoji: "🌍", flag: .hasMilesAndMore),
                BubbleChip(id: "hasEmirateSkywards",      label: "Emirates Skywards",    emoji: "🌍", flag: .hasEmirateSkywards),
                BubbleChip(id: "hasQantasFrequentFlyer",  label: "Qantas Frequent Flyer",emoji: "🌍", flag: .hasQantasFrequentFlyer),
                BubbleChip(id: "hasKrisFlyer",            label: "KrisFlyer (Singapore)",emoji: "🌍", flag: .hasKrisFlyer),
            ]),
            ChipSection(title: "Hotels", chips: [
                BubbleChip(id: "hasMarriottBonvoy",     label: "Marriott Bonvoy",     emoji: "🏨", flag: .hasMarriottBonvoy),
                BubbleChip(id: "hasHiltonHonors",       label: "Hilton Honors",       emoji: "🏨", flag: .hasHiltonHonors),
                BubbleChip(id: "hasWorldOfHyatt",       label: "World of Hyatt",      emoji: "🏨", flag: .hasWorldOfHyatt),
                BubbleChip(id: "hasIHGOneRewards",      label: "IHG One Rewards",     emoji: "🏨", flag: .hasIHGOneRewards),
                BubbleChip(id: "hasWyndhamRewards",     label: "Wyndham Rewards",     emoji: "🏨", flag: .hasWyndhamRewards),
                BubbleChip(id: "hasChoicePrivileges",   label: "Choice Privileges",   emoji: "🏨", flag: .hasChoicePrivileges),
                BubbleChip(id: "hasBestWesternRewards", label: "Best Western Rewards",emoji: "🏨", flag: .hasBestWesternRewards),
            ]),
            ChipSection(title: "Rental Cars", chips: [
                BubbleChip(id: "hasHertzGold",              label: "Hertz Gold",             emoji: "🚗", flag: .hasHertzGold),
                BubbleChip(id: "hasEnterpriseNationalPlus", label: "Enterprise/National Plus",emoji: "🚗", flag: .hasEnterpriseNationalPlus),
                BubbleChip(id: "hasAvisBudgetPreferred",    label: "Avis/Budget Preferred",  emoji: "🚗", flag: .hasAvisBudgetPreferred),
            ]),
        ]

        extraChips["subscriptions"] = [
            ChipSection(title: "Subscription Boxes", chips: [
                BubbleChip(id: "usesBeautyBox",         label: "Beauty Box",          emoji: "💄", flag: .usesBeautyBox),
                BubbleChip(id: "usesFabFitFun",         label: "FabFitFun",           emoji: "💄", flag: .usesFabFitFun),
                BubbleChip(id: "usesBespokePost",       label: "Bespoke Post",        emoji: "📦", flag: .usesBespokePost),
                BubbleChip(id: "usesWineClub",          label: "Wine Club",           emoji: "🍷", flag: .usesWineClub),
                BubbleChip(id: "usesCoffeeSubscription",label: "Coffee Subscription", emoji: "☕", flag: .usesCoffeeSubscription),
                BubbleChip(id: "usesKidsCrateBox",      label: "Kids Activity Box",   emoji: "🧸", flag: .usesKidsCrateBox),
                BubbleChip(id: "usesBookOfTheMonth",    label: "Book of the Month",   emoji: "📚", flag: .usesBookOfTheMonth),
                BubbleChip(id: "usesSnackBox",          label: "Snack Box",           emoji: "🍫", flag: .usesSnackBox),
                BubbleChip(id: "usesClothingBox",       label: "Clothing Box",        emoji: "👕", flag: .usesClothingBox),
            ]),
            ChipSection(title: "News & Reading", chips: [
                BubbleChip(id: "usesNewYorkTimes",        label: "New York Times",      emoji: "📰", flag: .usesNewYorkTimes),
                BubbleChip(id: "usesWashingtonPost",      label: "Washington Post",     emoji: "📰", flag: .usesWashingtonPost),
                BubbleChip(id: "usesWallStreetJournal",   label: "Wall Street Journal", emoji: "📰", flag: .usesWallStreetJournal),
                BubbleChip(id: "usesLocalNewspaper",      label: "Local Newspaper",     emoji: "📰", flag: .usesLocalNewspaper),
                BubbleChip(id: "usesMagazineSubscription",label: "Magazine Subscription", emoji: "📖", flag: .usesMagazineSubscription),
                BubbleChip(id: "usesBarnesAndNoble",      label: "Barnes & Noble",      emoji: "📚", flag: .usesBarnesAndNoble),
            ]),
            ChipSection(title: "Digital Accounts", chips: [
                BubbleChip(id: "usesAutoShipPetFood",     label: "Auto-Ship Pet Food",   emoji: "🐾", flag: .usesAutoShipPetFood),
                BubbleChip(id: "usesCloudInfrastructure", label: "Cloud Infrastructure", emoji: "☁️", flag: .usesCloudInfrastructure),
                BubbleChip(id: "usesMailOrderPharmacy",   label: "Mail-Order Pharmacy",  emoji: "💊", flag: .usesMailOrderPharmacy),
                BubbleChip(id: "usesAppleAppStore",       label: "Apple App Store",      emoji: "📱", flag: .usesAppleAppStore),
                BubbleChip(id: "usesGooglePlay",          label: "Google Play",          emoji: "📱", flag: .usesGooglePlay),
                BubbleChip(id: "usesApplePay",            label: "Apple Pay",            emoji: "💳", flag: .usesApplePay),
                BubbleChip(id: "usesGooglePay",           label: "Google Pay",           emoji: "💳", flag: .usesGooglePay),
                BubbleChip(id: "usesShopPay",             label: "Shop Pay",             emoji: "💳", flag: .usesShopPay),
                BubbleChip(id: "usesPatreonSubstack",     label: "Patreon / Substack",   emoji: "✍️", flag: .usesPatreonSubstack),
            ]),
        ]

        extraChips["community"] = [
            ChipSection(title: "Community & Giving", chips: [
                BubbleChip(id: "attendsReligiousInstitution", label: "Religious Institution",  emoji: "⛪", flag: .attendsReligiousInstitution),
                BubbleChip(id: "belongsToSocialClub",         label: "Social / Country Club",  emoji: "🎭", flag: .belongsToSocialClub),
                BubbleChip(id: "donatesCharitably",           label: "Charitable Donations",   emoji: "💝", flag: .donatesCharitably),
                BubbleChip(id: "hasPoliticalContributions",   label: "Political Contributions",emoji: "🗳️", flag: .hasPoliticalContributions),
            ]),
        ]

        extraChips["digital"] = [
            ChipSection(title: "Digital Identity", chips: [
                BubbleChip(id: "hasPersonalWebsite",           label: "Personal Website",      emoji: "🌐", flag: .hasPersonalWebsite),
                BubbleChip(id: "hasGoogleBusinessProfile",     label: "Google Business Profile",emoji: "🌐", flag: .hasGoogleBusinessProfile),
                BubbleChip(id: "usesDomainRegistrar",          label: "Domain Registrar",       emoji: "🌐", flag: .usesDomainRegistrar),
                BubbleChip(id: "usesPasswordManager",          label: "Password Manager",       emoji: "🔑", flag: .usesPasswordManager),
                BubbleChip(id: "hasProfessionalOnlineProfile", label: "Professional Online Profile", emoji: "💼", flag: .hasProfessionalOnlineProfile),
            ]),
        ]

        extraChips["recreation"] = [
            ChipSection(title: "Regional Recreation Networks", chips: [
                BubbleChip(id: "hasEpicPass",                   label: "Epic Pass",               emoji: "🎿", flag: .hasEpicPass),
                BubbleChip(id: "hasIkonPass",                   label: "Ikon Pass",                emoji: "🎿", flag: .hasIkonPass),
                BubbleChip(id: "usesInvitedClubs",              label: "Invited (ClubCorp)",      emoji: "⛳", flag: .usesInvitedClubs),
                BubbleChip(id: "usesTroonManagedClub",          label: "Troon-Managed Club",      emoji: "⛳", flag: .usesTroonManagedClub),
                BubbleChip(id: "usesFreedomBoatClub",           label: "Freedom Boat Club",       emoji: "⛵", flag: .usesFreedomBoatClub),
                BubbleChip(id: "usesCarefreeBoatClub",          label: "Carefree Boat Club",      emoji: "⛵", flag: .usesCarefreeBoatClub),
                BubbleChip(id: "usesTractorSupplyNeighborsClub",label: "Tractor Supply Neighbor's Club", emoji: "🚜", flag: .usesTractorSupplyNeighborsClub),
                BubbleChip(id: "hasFarmBureauMembership",       label: "Farm Bureau",             emoji: "🌾", flag: .hasFarmBureauMembership),
                BubbleChip(id: "usesBassProCabelasClub",        label: "Bass Pro / Cabela's CLUB", emoji: "🎣", flag: .usesBassProCabelasClub),
                BubbleChip(id: "hasConservationOrgMembership",  label: "Conservation Org (DU, RMEF, TU)", emoji: "🦆", flag: .hasConservationOrgMembership),
            ]),
        ]
    }
}

// MARK: - Container View

struct LifestyleInterviewView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    let onComplete: () -> Void

    @State private var vm: LifestyleViewModel

    init(move: Move, onComplete: @escaping () -> Void) {
        self.move = move
        self.onComplete = onComplete
        self._vm = State(initialValue: LifestyleViewModel())
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            // Progress dots
            VStack {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == vm.currentScreen ? Theme.accentPrimary : Theme.backgroundElevated)
                            .frame(width: i == vm.currentScreen ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: vm.currentScreen)
                    }
                }
                .padding(.top, 60)
                Spacer()
            }

            Group {
                switch vm.currentScreen {
                case 0: quickQuestionsScreen
                case 1: financialScreen
                case 2: optionalExtrasScreen
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.3), value: vm.currentScreen)
        }
    }

    // MARK: - Screen 1: Quick Yes/No questions

    private var quickQuestionsScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A few quick\nquestions")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(4)
                    Text("We'll use these to build your personalized task list.")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textSecondary)
                        .lineSpacing(3)
                }

                VStack(spacing: 12) {
                    YesNoCard(
                        question: "Kids at home?",
                        emoji: "👧",
                        isSelected: vm.hasKids,
                        onToggle: { vm.hasKids.toggle() }
                    )
                    YesNoCard(
                        question: "Pets?",
                        emoji: "🐾",
                        isSelected: vm.hasPets,
                        onToggle: { vm.hasPets.toggle() }
                    )
                    YesNoCard(
                        question: "Owning your new home?",
                        emoji: "🏡",
                        isSelected: vm.ownsHome,
                        onToggle: { vm.ownsHome.toggle() }
                    )

                    // WS5 — shown only when the parent toggle is on, additive to it
                    if vm.hasKids {
                        HStack {
                            Text("How many kids?")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Stepper("\(vm.childCount)", value: $vm.childCount, in: 1...8)
                                .fixedSize()
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding(14)
                        .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 14))
                    }

                    if vm.hasPets {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What kind?")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                            HStack(spacing: 8) {
                                ForEach(PetSpecies.allCases, id: \.self) { species in
                                    let isOn = vm.petSpecies.contains(species)
                                    Button {
                                        if isOn { vm.petSpecies.remove(species) } else { vm.petSpecies.insert(species) }
                                    } label: {
                                        Text(species.displayLabel)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(isOn ? .white : Theme.textSecondary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(isOn ? Theme.accentPrimary : Theme.backgroundElevated, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(14)
                        .background(Theme.backgroundElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            Spacer()

            continueButton("Looks good →") { vm.next() }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    // MARK: - Screen 2: Financial accounts

    private var financialScreen: some View {
        FinancialScreenView(
            selectedInstitutions: Binding(
                get: { vm.selectedInstitutions },
                set: { vm.selectedInstitutions = $0 }
            ),
            stepIndex: 1,
            totalSteps: 3,
            stateBucket: move.originStateBucket ?? move.destinationStateBucket,
            onBack: { vm.back() },
            onFinish: { vm.next() }
        )
    }

    // MARK: - Screen 3: Optional extras

    private var optionalExtrasScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("We found")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(estimatedTaskCount)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.accentSuccess)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: estimatedTaskCount)
                        Text("tasks for you.")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Text("Want to add more?")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textSecondary)
                }

                // Category toggles
                let categories: [(id: String, label: String, emoji: String)] = [
                    ("shopping",  "Shopping & Delivery",      "📦"),
                    ("streaming", "Streaming & Cable",         "📺"),
                    ("fitness",   "Fitness & Wellness",        "💪"),
                    ("transport", "Vehicles & Travel",         "🚗"),
                    ("life",      "Life & Finance",            "💼"),
                ]

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(categories, id: \.id) { cat in
                            OptionalCategoryCard(
                                category: cat.id,
                                label: cat.label,
                                emoji: cat.emoji,
                                chips: vm.extraChips[cat.id] ?? [],
                                isExpanded: vm.expandedCategories.contains(cat.id),
                                onToggle: {
                                    withAnimation(.spring(response: 0.35)) {
                                        if vm.expandedCategories.contains(cat.id) {
                                            vm.expandedCategories.remove(cat.id)
                                        } else {
                                            vm.expandedCategories.insert(cat.id)
                                        }
                                    }
                                },
                                onChipTap: { chip in vm.toggleExtraChip(chip, in: cat.id) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 320)
            }

            Spacer()

            HStack(spacing: 12) {
                backButton { vm.back() }
                continueButton("Build my list →") { commitAndComplete() }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    private var estimatedTaskCount: Int {
        // Real count from the same generator that builds the actual checklist — updates
        // live as the user taps chips, and always matches what they land on at the dashboard.
        ChecklistGenerator.matchingItems(flags: vm.allActiveFlags).count + vm.selectedInstitutions.count
    }

    // MARK: - Shared components

    @ViewBuilder
    private func continueButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Theme.accentPrimary, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 54, height: 54)
                .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Commit

    private func commitAndComplete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let profile = LifestyleProfile()
        profile.move = move
        var finalFlags = vm.allActiveFlags

        func applyRegionalFlags(for zip: String) {
            let clean = zip.replacingOccurrences(of: " ", with: "").uppercased()
            if clean.count == 6 && clean.first!.isLetter {
                finalFlags.insert(.isCanadian)
                switch clean.first! {
                case "A": finalFlags.insert(.inNewfoundland)
                case "B": finalFlags.insert(.inNovaScotia)
                case "C": finalFlags.insert(.inPEI)
                case "E": finalFlags.insert(.inNewBrunswick)
                case "G", "H", "J": finalFlags.insert(.inQuebec)
                case "K", "L", "M", "N", "P": finalFlags.insert(.inOntario)
                case "R": finalFlags.insert(.inManitoba)
                case "S": finalFlags.insert(.inSaskatchewan)
                case "T": finalFlags.insert(.inAlberta)
                case "V": finalFlags.insert(.inBritishColumbia)
                case "X": finalFlags.insert(.inNorthwestTerritories)
                case "Y": finalFlags.insert(.inYukon)
                default: break
                }
            } else if clean.count >= 5, Int(clean.prefix(2)) != nil {
                finalFlags.insert(.isAmerican)
            }
        }

        if let origin = move.originZip { applyRegionalFlags(for: origin) }
        applyRegionalFlags(for: move.destinationZip)

        profile.activeFlags = finalFlags
        // WS5 — only persisted if the user actually confirmed the parent toggle;
        // otherwise stays nil/empty, matching every other "unset" field on this model.
        if vm.hasKids { profile.childCount = vm.childCount }
        if vm.hasPets { profile.petSpecies = vm.petSpecies }
        modelContext.insert(profile)
        move.lifestyleProfile = profile

        var institutions: [FinancialInstitution] = []
        for known in vm.selectedInstitutions {
            let fi = FinancialInstitution(name: known.name, initials: known.initials,
                                          colorHex: known.colorHex, type: known.type,
                                          websiteURL: known.websiteURL)
            fi.move = move
            modelContext.insert(fi)
            move.institutions.append(fi)
            institutions.append(fi)
        }

        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: institutions)
        for task in tasks {
            task.move = move
            modelContext.insert(task)
        }
        move.tasks = tasks
        modelContext.saveOrLog()

        withAnimation(.easeInOut(duration: 0.4)) { onComplete() }
    }
}

// MARK: - Yes/No Card

struct YesNoCard: View {
    let question: String
    let emoji: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Theme.accentPrimary.opacity(0.15) : Theme.backgroundElevated,
                                in: RoundedRectangle(cornerRadius: 12))

                Text(question)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Theme.accentPrimary : Theme.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Theme.accentPrimary.opacity(0.08) : Theme.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Theme.accentPrimary.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Optional Category Card

struct OptionalCategoryCard: View {
    let category: String
    let label: String
    let emoji: String
    let chips: [ChipSection]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onChipTap: (BubbleChip) -> Void

    private var selectedCount: Int {
        chips.flatMap { $0.chips }.filter { $0.isSelected }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(emoji).font(.system(size: 20))
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    if selectedCount > 0 {
                        Text("\(selectedCount) selected")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.accentPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accentPrimary.opacity(0.12), in: Capsule())
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(chips) { section in
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(section.chips) { chip in
                                Button {
                                    onChipTap(chip)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(chip.emoji).font(.system(size: 14))
                                        Text(chip.label)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(chip.isSelected ? .white : Theme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        chip.isSelected ? Theme.accentPrimary : Theme.backgroundElevated,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.15), value: chip.isSelected)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selectedCount > 0 ? Theme.accentPrimary.opacity(0.3) : Theme.hairline, lineWidth: 1)
        )
    }
}
