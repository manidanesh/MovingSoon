// ItemCatalog+Canada.swift — Canadian Federal, Provincial, Utility, and Retail Services
import Foundation

extension ItemCatalog {

    static var allCanada: [CatalogItem] {
        canadaFederal + canadaProvincial + canadaTelecom + canadaUtilities + canadaRetail
    }

    // MARK: - 🍁 Federal Government

    static let canadaFederal: [CatalogItem] = [
        CatalogItem(id: "canada_post", title: "Canada Post Mail Forwarding", emoji: "📬",
                    category: .postal, priority: .critical, tMinusDays: -30,
                    deepLinkURL: URL(string: "https://www.canadapost-postescanada.ca/cpc/en/personal/receiving/manage-mail/mail-forwarding.page"),
                    brandColorHex: "#0033A0", isHeroItem: true,
                    requires: [.isCanadian], reviewFamily: .identity),
        CatalogItem(id: "cra_address", title: "CRA (Canada Revenue Agency)", emoji: "🍁",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/about-your-tax-return/change-your-address.html"),
                    brandColorHex: "#D80621",
                    requires: [.isCanadian], reviewFamily: .identity),
        CatalogItem(id: "service_canada", title: "Service Canada (EI, CPP, OAS)", emoji: "🛡️",
                    category: .government, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.canada.ca/en/employment-social-development/services/my-account.html"),
                    brandColorHex: "#333333",
                    requires: [.isCanadian], reviewFamily: .identity),
        CatalogItem(id: "elections_canada", title: "Elections Canada (Voter Registration)", emoji: "🗳️",
                    category: .government, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.elections.ca/"),
                    brandColorHex: "#000000",
                    requires: [.isCanadian], reviewFamily: .identity),
        CatalogItem(id: "passport_canada", title: "Passport Canada", emoji: "🛂",
                    category: .government, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.canada.ca/en/immigration-refugees-citizenship/services/canadian-passports.html"),
                    brandColorHex: "#00205B",
                    requires: [.isCanadian], reviewFamily: .identity),
    ]

    // MARK: - 🍁 Provincial Government (Dynamic by Province Flag)

    static let canadaProvincial: [CatalogItem] = [
        // Ontario
        CatalogItem(id: "service_ontario", title: "ServiceOntario (Health Card & Driver's License)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.ontario.ca/page/serviceontario"),
                    brandColorHex: "#000000",
                    requires: [.isCanadian, .inOntario], poiCategory: .dmv,
                    placeSearchName: "ServiceOntario", placeNameAliases: ["ServiceOntario", "Service Ontario"], reviewFamily: .identity),

        // British Columbia
        CatalogItem(id: "icbc", title: "ICBC (Driver's License & Auto Insurance)", emoji: "🚗",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.icbc.com/"),
                    brandColorHex: "#003366",
                    requires: [.isCanadian, .inBritishColumbia], poiCategory: .dmv,
                    placeSearchName: "ICBC driver licensing", placeNameAliases: ["ICBC"], reviewFamily: .identity),
        CatalogItem(id: "health_bc", title: "Health Insurance BC (MSP)", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www2.gov.bc.ca/gov/content/health/health-drug-coverage/msp"),
                    brandColorHex: "#234075",
                    requires: [.isCanadian, .inBritishColumbia], reviewFamily: .identity),

        // Quebec
        CatalogItem(id: "saaq", title: "SAAQ (Driver's License & Vehicle Registration)", emoji: "🚗",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://saaq.gouv.qc.ca/en/"),
                    brandColorHex: "#003399",
                    requires: [.isCanadian, .inQuebec], poiCategory: .dmv,
                    placeSearchName: "SAAQ", placeNameAliases: ["SAAQ"], reviewFamily: .identity),
        CatalogItem(id: "ramq", title: "RAMQ (Health Insurance)", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.ramq.gouv.qc.ca/en"),
                    brandColorHex: "#0099CC",
                    requires: [.isCanadian, .inQuebec], reviewFamily: .identity),

        // Alberta
        CatalogItem(id: "service_alberta", title: "Service Alberta (Registry Agent)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.alberta.ca/service-alberta.aspx"),
                    brandColorHex: "#003366",
                    requires: [.isCanadian, .inAlberta], poiCategory: .dmv,
                    placeSearchName: "Alberta registry agent", placeNameAliases: ["Registry", "Registries"], reviewFamily: .identity),
        CatalogItem(id: "ahcip", title: "AHCIP (Alberta Health Care)", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.alberta.ca/ahcip-update-status.aspx"),
                    brandColorHex: "#003366",
                    requires: [.isCanadian, .inAlberta], reviewFamily: .identity),

        // Manitoba — MPI uniquely bundles driver's licence, vehicle registration, and
        // auto insurance into one crown corporation (same model as ICBC/SAAQ/SGI).
        CatalogItem(id: "mpi", title: "MPI (Driver's Licence, Registration & Auto Insurance)", emoji: "🚗",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.mpi.mb.ca/"),
                    brandColorHex: "#00563F",
                    requires: [.isCanadian, .inManitoba], poiCategory: .dmv,
                    placeSearchName: "Manitoba Public Insurance", placeNameAliases: ["Manitoba Public Insurance", "MPI"], reviewFamily: .identity),
        CatalogItem(id: "manitoba_health", title: "Manitoba Health (Health Card)", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.gov.mb.ca/health/"),
                    brandColorHex: "#004B87",
                    requires: [.isCanadian, .inManitoba], reviewFamily: .identity),

        // Saskatchewan — SGI is the same crown-corp model as MPI/ICBC.
        CatalogItem(id: "sgi", title: "SGI (Driver's Licence, Registration & Auto Insurance)", emoji: "🚗",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.sgi.sk.ca/"),
                    brandColorHex: "#00843D",
                    requires: [.isCanadian, .inSaskatchewan], poiCategory: .dmv,
                    placeSearchName: "SGI", placeNameAliases: ["SGI"], reviewFamily: .identity),
        CatalogItem(id: "ehealth_sk", title: "eHealth Saskatchewan (Health Card)", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.ehealthsask.ca/"),
                    brandColorHex: "#005DAA",
                    requires: [.isCanadian, .inSaskatchewan], reviewFamily: .identity),

        // Nova Scotia
        CatalogItem(id: "access_ns", title: "Access Nova Scotia (Driver's Licence & Registration)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://novascotia.ca/"),
                    brandColorHex: "#00205B",
                    requires: [.isCanadian, .inNovaScotia], poiCategory: .dmv,
                    placeSearchName: "Access Nova Scotia", placeNameAliases: ["Access Nova Scotia"], reviewFamily: .identity),
        CatalogItem(id: "msi_ns", title: "MSI — Nova Scotia Health Card", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#00A0DF",
                    requires: [.isCanadian, .inNovaScotia], reviewFamily: .identity),

        // New Brunswick
        CatalogItem(id: "snb", title: "Service New Brunswick (Driver's Licence & Registration)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www2.snb.ca/"),
                    brandColorHex: "#00447C",
                    requires: [.isCanadian, .inNewBrunswick], poiCategory: .dmv,
                    placeSearchName: "Service New Brunswick", placeNameAliases: ["Service New Brunswick"], reviewFamily: .identity),
        CatalogItem(id: "medicare_nb", title: "New Brunswick Medicare (Health Card)", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#4E9F3D",
                    requires: [.isCanadian, .inNewBrunswick], reviewFamily: .identity),

        // Newfoundland and Labrador
        CatalogItem(id: "service_nl", title: "Service NL (Driver's Licence & Registration)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.gov.nl.ca/"),
                    brandColorHex: "#00274D",
                    requires: [.isCanadian, .inNewfoundland], poiCategory: .dmv,
                    placeSearchName: "Motor Registration Newfoundland", placeNameAliases: ["Motor Registration"], reviewFamily: .identity),
        CatalogItem(id: "mcp_nl", title: "MCP — Newfoundland & Labrador Health Card", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#006B54",
                    requires: [.isCanadian, .inNewfoundland], reviewFamily: .identity),

        // Prince Edward Island
        CatalogItem(id: "access_pei", title: "Access PEI (Driver's Licence & Registration)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.princeedwardisland.ca/"),
                    brandColorHex: "#C8102E",
                    requires: [.isCanadian, .inPEI], poiCategory: .dmv,
                    placeSearchName: "Access PEI", placeNameAliases: ["Access PEI"], reviewFamily: .identity),
        CatalogItem(id: "health_pei", title: "Health PEI (Health Card)", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#00563F",
                    requires: [.isCanadian, .inPEI], reviewFamily: .identity),

        // Territories — one combined item each; lower confidence on exact department
        // names/sub-pages up here, so these link to the territorial government's root
        // site rather than a guessed deep link.
        CatalogItem(id: "yukon_gov", title: "Yukon Government Services (Licence & Health Card)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://yukon.ca/"),
                    brandColorHex: "#003DA5",
                    requires: [.isCanadian, .inYukon], poiCategory: .dmv, reviewFamily: .identity),
        CatalogItem(id: "nwt_gov", title: "NWT Government Services (Licence & Health Care Plan)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.gov.nt.ca/"),
                    brandColorHex: "#005EB8",
                    requires: [.isCanadian, .inNorthwestTerritories], poiCategory: .dmv, reviewFamily: .identity),
        CatalogItem(id: "nunavut_gov", title: "Nunavut Government Services (Licence & Health Card)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: 7,
                    deepLinkURL: URL(string: "https://www.gov.nu.ca/"),
                    brandColorHex: "#8C1D40",
                    requires: [.isCanadian, .inNunavut], poiCategory: .dmv, reviewFamily: .identity),
    ]

    // MARK: - 📶 Telecom (The Big 3 + Regional)

    static let canadaTelecom: [CatalogItem] = [
        CatalogItem(id: "bell_canada", title: "Bell Canada", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.bell.ca/"),
                    brandColorHex: "#0055A4",
                    requiresAny: [.isCanadian], reviewFamily: .home, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "rogers", title: "Rogers Communications", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.rogers.com/"),
                    brandColorHex: "#DA291C",
                    requiresAny: [.isCanadian], reviewFamily: .home, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "telus", title: "TELUS", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.telus.com/"),
                    brandColorHex: "#4B286D",
                    requiresAny: [.isCanadian], reviewFamily: .home, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "videotron", title: "Videotron", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://videotron.com/"),
                    brandColorHex: "#FFD100",
                    requires: [.isCanadian, .inQuebec], reviewFamily: .home, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "shaw", title: "Shaw (Rogers)", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.shaw.ca/"),
                    brandColorHex: "#00AEEF",
                    requiresAny: [.inBritishColumbia, .inAlberta, .inManitoba, .inSaskatchewan], reviewFamily: .home, requiresConfirmation: true, moveAction: .reviewTransfer),
    ]

    // MARK: - ⚡ Utilities (Provincial Crown Corps & Monopolies)

    static let canadaUtilities: [CatalogItem] = [
        CatalogItem(id: "hydro_one", title: "Hydro One", emoji: "⚡",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    deepLinkURL: URL(string: "https://www.hydroone.com/"),
                    brandColorHex: "#F37021",
                    requires: [.isCanadian, .inOntario], reviewFamily: .home, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "enbridge_gas", title: "Enbridge Gas", emoji: "🔥",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    deepLinkURL: URL(string: "https://www.enbridgegas.com/"),
                    brandColorHex: "#FFCB05",
                    requires: [.isCanadian, .inOntario], reviewFamily: .home, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "bc_hydro", title: "BC Hydro", emoji: "⚡",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    deepLinkURL: URL(string: "https://www.bchydro.com/"),
                    brandColorHex: "#005EB8",
                    requires: [.isCanadian, .inBritishColumbia], reviewFamily: .home, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "fortis_bc", title: "FortisBC", emoji: "🔥",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    deepLinkURL: URL(string: "https://www.fortisbc.com/"),
                    brandColorHex: "#0072CE",
                    requires: [.isCanadian, .inBritishColumbia], reviewFamily: .home, requiresConfirmation: true, moveAction: .reviewTransfer),
        CatalogItem(id: "hydro_quebec", title: "Hydro-Québec", emoji: "⚡",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    deepLinkURL: URL(string: "https://www.hydroquebec.com/"),
                    brandColorHex: "#F37021",
                    requires: [.isCanadian, .inQuebec], reviewFamily: .home, requiresConfirmation: true, moveAction: .reviewTransfer),
    ]

    // MARK: - 🛒 Retail, Loyalty & Fitness

    static let canadaRetail: [CatalogItem] = [
        CatalogItem(id: "pc_optimum", title: "PC Optimum (Shoppers / Loblaws)", emoji: "🛒",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.pcoptimum.ca/"),
                    brandColorHex: "#E31837",
                    requires: [.isCanadian], reviewFamily: .shopping, requiresConfirmation: true),
        CatalogItem(id: "scene_plus", title: "Scene+ (Scotiabank / Cineplex / Sobeys)", emoji: "🎬",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.sceneplus.ca/"),
                    brandColorHex: "#000000",
                    requires: [.isCanadian], reviewFamily: .shopping, requiresConfirmation: true),
        CatalogItem(id: "triangle_rewards", title: "Triangle Rewards (Canadian Tire)", emoji: "🔧",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://triangle.canadiantire.ca/"),
                    brandColorHex: "#E31837",
                    requires: [.isCanadian], reviewFamily: .shopping, requiresConfirmation: true),
        CatalogItem(id: "goodlife_fitness", title: "GoodLife Fitness", emoji: "💪",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.goodlifefitness.com/"),
                    brandColorHex: "#C41230",
                    requires: [.isCanadian], poiCategory: .gym,
                    placeSearchName: "GoodLife Fitness", placeNameAliases: ["GoodLife Fitness"], reviewFamily: .shopping, requiresConfirmation: true),
    ]
}
