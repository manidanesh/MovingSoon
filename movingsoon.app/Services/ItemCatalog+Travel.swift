// ItemCatalog+Travel.swift — Airlines, Hotels, Rental Cars, Transit & Vehicle Programs
import Foundation

extension ItemCatalog {

    static var allTravel: [CatalogItem] {
        airlines + hotels + rentalCars + transitCards + vehiclePrograms
    }

    // MARK: - ✈️ Airlines — US Carriers

    static let airlines: [CatalogItem] = [
        CatalogItem(id: "delta_skymiles", title: "Delta SkyMiles Address", emoji: "✈️",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.delta.com/us/en/skymiles/overview"),
                    brandColorHex: "#E01933", requires: [.hasDeltaSkyMiles], poiCategory: .airport),
        CatalogItem(id: "united_mileageplus", title: "United MileagePlus Address", emoji: "✈️",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.united.com/en/us/account"),
                    brandColorHex: "#005DAA", requires: [.hasUnitedMileagePlus], poiCategory: .airport),
        CatalogItem(id: "american_aadvantage", title: "American AAdvantage Address", emoji: "✈️",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.aa.com/loyalty/accrual/earnMiles.do"),
                    brandColorHex: "#0078D2", requires: [.hasAmericanAAdvantage], poiCategory: .airport),
        CatalogItem(id: "southwest_rapidrewards", title: "Southwest Rapid Rewards Address", emoji: "✈️",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.southwest.com/rapid-rewards/"),
                    brandColorHex: "#304CB2", requires: [.hasSouthwestRapidRewards], poiCategory: .airport),
        CatalogItem(id: "alaska_mileageplan", title: "Alaska Mileage Plan Address", emoji: "✈️",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.alaskaair.com/content/mileage-plan"),
                    brandColorHex: "#00467F", requires: [.hasAlaskaMileagePlan], poiCategory: .airport),
        CatalogItem(id: "jetblue_trueblue", title: "JetBlue TrueBlue Address", emoji: "✈️",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://trueblue.jetblue.com/"),
                    brandColorHex: "#0033A0", requires: [.hasJetBlueTrueBlue], poiCategory: .airport),
        CatalogItem(id: "spirit_freespirit", title: "Spirit Free Spirit Address", emoji: "✈️",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.spirit.com/FreeSpiritAccount/Login"),
                    brandColorHex: "#FFD700", requires: [.hasSpiritFreeSpirit], poiCategory: .airport),
        CatalogItem(id: "frontier_miles", title: "Frontier Miles Address", emoji: "✈️",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.flyfrontier.com/frontier-miles/"),
                    brandColorHex: "#006F3C", requires: [.hasFrontierMiles], poiCategory: .airport),

        // MARK: - Canadian Airlines
        CatalogItem(id: "aircanada_aeroplan", title: "Air Canada Aeroplan Address", emoji: "✈️",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.aircanada.com/ca/en/aco/home/aeroplan.html"),
                    brandColorHex: "#C41E3A", requires: [.hasAirCanadaAeroplan], poiCategory: .airport),
        CatalogItem(id: "westjet_rewards", title: "WestJet Rewards Address", emoji: "✈️",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.westjet.com/en-ca/westjet-rewards"),
                    brandColorHex: "#00A0DF", requires: [.hasWestJetRewards], poiCategory: .airport),
        CatalogItem(id: "porter_viporter", title: "Porter VIPorter Address", emoji: "✈️",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.flyporter.com/en-ca/viporter"),
                    brandColorHex: "#1B3D6E", requires: [.hasPorterVIPorter], poiCategory: .airport),

        // MARK: - International Airlines
        CatalogItem(id: "ba_execclub", title: "British Airways Executive Club Address", emoji: "✈️",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.britishairways.com/en-us/executive-club"),
                    brandColorHex: "#075AAA", requires: [.hasBritishAirwaysExecClub], poiCategory: .airport),
        CatalogItem(id: "flying_blue", title: "Air France / KLM Flying Blue Address", emoji: "✈️",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.flyingblue.com/"),
                    brandColorHex: "#003087", requires: [.hasFlyingBlue], poiCategory: .airport),
        CatalogItem(id: "miles_and_more", title: "Lufthansa Miles & More Address", emoji: "✈️",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.miles-and-more.com/"),
                    brandColorHex: "#05164D", requires: [.hasMilesAndMore], poiCategory: .airport),
        CatalogItem(id: "emirates_skywards", title: "Emirates Skywards Address", emoji: "✈️",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.emirates.com/us/english/skywards/"),
                    brandColorHex: "#C8102E", requires: [.hasEmirateSkywards], poiCategory: .airport),
        CatalogItem(id: "qantas_ff", title: "Qantas Frequent Flyer Address", emoji: "✈️",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.qantas.com/au/en/frequent-flyer.html"),
                    brandColorHex: "#EE0000", requires: [.hasQantasFrequentFlyer], poiCategory: .airport),
        CatalogItem(id: "krisflyer", title: "Singapore Airlines KrisFlyer Address", emoji: "✈️",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.singaporeair.com/en_UK/us/ppsclub-krisflyer/"),
                    brandColorHex: "#003DA5", requires: [.hasKrisFlyer], poiCategory: .airport),
    ]

    // MARK: - 🏨 Hotel Loyalty Programs

    static let hotels: [CatalogItem] = [
        CatalogItem(id: "marriott_bonvoy", title: "Marriott Bonvoy Address", emoji: "🏨",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.marriott.com/loyalty/myAccount/default.mi"),
                    brandColorHex: "#8B1A1A", requires: [.hasMarriottBonvoy], poiCategory: .hotel),
        CatalogItem(id: "hilton_honors", title: "Hilton Honors Address", emoji: "🏨",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.hilton.com/en/hilton-honors/"),
                    brandColorHex: "#003B6F", requires: [.hasHiltonHonors], poiCategory: .hotel),
        CatalogItem(id: "world_of_hyatt", title: "World of Hyatt Address", emoji: "🏨",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://world.hyatt.com/content/gp/en/index.html"),
                    brandColorHex: "#96172E", requires: [.hasWorldOfHyatt], poiCategory: .hotel),
        CatalogItem(id: "ihg_rewards", title: "IHG One Rewards Address", emoji: "🏨",
                    category: .travel, priority: .medium, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.ihg.com/onerewards/content/us/en/home"),
                    brandColorHex: "#003D66", requires: [.hasIHGOneRewards], poiCategory: .hotel),
        CatalogItem(id: "wyndham_rewards", title: "Wyndham Rewards Address", emoji: "🏨",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.wyndhamhotels.com/wyndham-rewards"),
                    brandColorHex: "#005CAB", requires: [.hasWyndhamRewards], poiCategory: .hotel),
        CatalogItem(id: "choice_privileges", title: "Choice Privileges Address", emoji: "🏨",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.choicehotels.com/choice-privileges"),
                    brandColorHex: "#004B87", requires: [.hasChoicePrivileges], poiCategory: .hotel),
        CatalogItem(id: "bestwestern_rewards", title: "Best Western Rewards Address", emoji: "🏨",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.bestwestern.com/en_US/best-western-rewards.html"),
                    brandColorHex: "#003580", requires: [.hasBestWesternRewards], poiCategory: .hotel),
    ]

    // MARK: - 🚗 Rental Car Programs

    static let rentalCars: [CatalogItem] = [
        CatalogItem(id: "hertz_gold", title: "Hertz Gold Plus Rewards Address", emoji: "🚗",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.hertz.com/rentacar/member/login/index.jsp"),
                    brandColorHex: "#FFB700", requires: [.hasHertzGold], poiCategory: .rentalCar),
        CatalogItem(id: "enterprise_national", title: "Enterprise / National Profile Address", emoji: "🚗",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.enterprise.com/en/profile.html"),
                    brandColorHex: "#00853E", requires: [.hasEnterpriseNationalPlus], poiCategory: .rentalCar),
        CatalogItem(id: "avis_budget", title: "Avis / Budget Preferred Address", emoji: "🚗",
                    category: .travel, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.avis.com/en/home"),
                    brandColorHex: "#CC0000", requires: [.hasAvisBudgetPreferred], poiCategory: .rentalCar),
    ]

    // MARK: - 🚇 Transit Cards

    static let transitCards: [CatalogItem] = [
        CatalogItem(id: "presto_card", title: "PRESTO Card Account Address", emoji: "🚇",
                    category: .travel, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.prestocard.ca/en/"),
                    brandColorHex: "#00843D", requires: [.hasPrestoCard]),
        CatalogItem(id: "compass_card", title: "Compass Card Account Address", emoji: "🚇",
                    category: .travel, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.compasscard.ca/"),
                    brandColorHex: "#009CDE", requires: [.hasCompassCard]),
        CatalogItem(id: "nyc_metro_card", title: "NYC MetroCard / OMNY Address", emoji: "🚇",
                    category: .travel, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://omny.info/"),
                    brandColorHex: "#0039A6", requires: [.hasMetroCard]),
        CatalogItem(id: "clipper_card", title: "Clipper Card Account Address", emoji: "🚇",
                    category: .travel, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.clippercard.com/ClipperWeb/"),
                    brandColorHex: "#00ADEF", requires: [.hasClipperCard]),
        CatalogItem(id: "ventra_card", title: "Ventra Card Account Address", emoji: "🚇",
                    category: .travel, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.ventrachicago.com/"),
                    brandColorHex: "#005DAA", requires: [.hasVentraCard]),
        CatalogItem(id: "breez_card", title: "Breeze / MARTA Card Address", emoji: "🚇",
                    category: .travel, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.breezecard.com/"),
                    brandColorHex: "#004B87", requires: [.hasBreezCard]),
        CatalogItem(id: "other_transit_card", title: "Transit Card / Pass Account", emoji: "🚇",
                    category: .travel, priority: .medium, tMinusDays: -7,
                    brandColorHex: "#626567", requires: [.hasOtherTransitCard]),
    ]

    // MARK: - 🔧 Vehicle Programs

    static let vehiclePrograms: [CatalogItem] = [
        CatalogItem(id: "aaa_membership", title: "AAA Membership Address", emoji: "🔧",
                    category: .travel, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.aaa.com/"),
                    brandColorHex: "#003087", requiresAny: [.hasCar, .hasMotorcycle]),
        CatalogItem(id: "toll_transponder", title: "Toll Transponder (E-ZPass / FasTrak / SunPass)", emoji: "🛣️",
                    category: .travel, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.e-zpassiag.com/"),
                    brandColorHex: "#1B4F72", requires: [.hasTollRoads]),
        CatalogItem(id: "toll_407etr", title: "407 ETR Transponder Account (Ontario)", emoji: "🛣️",
                    category: .travel, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.407etr.com/en/index.html"),
                    brandColorHex: "#003DA5", requires: [.hasTollRoads]),
        CatalogItem(id: "rideshare_uber", title: "Uber Home Address", emoji: "🚕",
                    category: .travel, priority: .medium, tMinusDays: 1,
                    deepLinkURL: URL(string: "https://riders.uber.com/"),
                    brandColorHex: "#141414", requiresAny: [.usesRideShare]),
        CatalogItem(id: "rideshare_lyft", title: "Lyft Home Address", emoji: "🚕",
                    category: .travel, priority: .medium, tMinusDays: 1,
                    deepLinkURL: URL(string: "https://account.lyft.com/"),
                    brandColorHex: "#FF00BF", requiresAny: [.usesRideShare]),
    ]
}
