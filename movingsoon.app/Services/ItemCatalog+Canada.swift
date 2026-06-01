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
                    requires: [.isCanadian]),
        CatalogItem(id: "cra_address", title: "CRA (Canada Revenue Agency)", emoji: "🍁",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/about-your-tax-return/change-your-address.html"),
                    brandColorHex: "#D80621",
                    requires: [.isCanadian]),
        CatalogItem(id: "service_canada", title: "Service Canada (EI, CPP, OAS)", emoji: "🛡️",
                    category: .government, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.canada.ca/en/employment-social-development/services/my-account.html"),
                    brandColorHex: "#333333",
                    requires: [.isCanadian]),
        CatalogItem(id: "elections_canada", title: "Elections Canada (Voter Registration)", emoji: "🗳️",
                    category: .government, priority: .high, tMinusDays: -7,
                    deepLinkURL: URL(string: "https://www.elections.ca/"),
                    brandColorHex: "#000000",
                    requires: [.isCanadian]),
        CatalogItem(id: "passport_canada", title: "Passport Canada", emoji: "🛂",
                    category: .government, priority: .low, tMinusDays: 14,
                    deepLinkURL: URL(string: "https://www.canada.ca/en/immigration-refugees-citizenship/services/canadian-passports.html"),
                    brandColorHex: "#00205B",
                    requires: [.isCanadian]),
    ]

    // MARK: - 🍁 Provincial Government (Dynamic by Province Flag)

    static let canadaProvincial: [CatalogItem] = [
        // Ontario
        CatalogItem(id: "service_ontario", title: "ServiceOntario (Health Card & Driver's License)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.ontario.ca/page/serviceontario"),
                    brandColorHex: "#000000",
                    requires: [.isCanadian, .inOntario]),
        
        // British Columbia
        CatalogItem(id: "icbc", title: "ICBC (Driver's License & Auto Insurance)", emoji: "🚗",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.icbc.com/"),
                    brandColorHex: "#003366",
                    requires: [.isCanadian, .inBritishColumbia]),
        CatalogItem(id: "health_bc", title: "Health Insurance BC (MSP)", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www2.gov.bc.ca/gov/content/health/health-drug-coverage/msp"),
                    brandColorHex: "#234075",
                    requires: [.isCanadian, .inBritishColumbia]),

        // Quebec
        CatalogItem(id: "saaq", title: "SAAQ (Driver's License & Vehicle Registration)", emoji: "🚗",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://saaq.gouv.qc.ca/en/"),
                    brandColorHex: "#003399",
                    requires: [.isCanadian, .inQuebec]),
        CatalogItem(id: "ramq", title: "RAMQ (Health Insurance)", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.ramq.gouv.qc.ca/en"),
                    brandColorHex: "#0099CC",
                    requires: [.isCanadian, .inQuebec]),

        // Alberta
        CatalogItem(id: "service_alberta", title: "Service Alberta (Registry Agent)", emoji: "🪪",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.alberta.ca/service-alberta.aspx"),
                    brandColorHex: "#003366",
                    requires: [.isCanadian, .inAlberta]),
        CatalogItem(id: "ahcip", title: "AHCIP (Alberta Health Care)", emoji: "⚕️",
                    category: .government, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.alberta.ca/ahcip-update-status.aspx"),
                    brandColorHex: "#003366",
                    requires: [.isCanadian, .inAlberta]),
    ]

    // MARK: - 📶 Telecom (The Big 3 + Regional)

    static let canadaTelecom: [CatalogItem] = [
        CatalogItem(id: "bell_canada", title: "Bell Canada", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.bell.ca/"),
                    brandColorHex: "#0055A4",
                    requiresAny: [.isCanadian]),
        CatalogItem(id: "rogers", title: "Rogers Communications", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.rogers.com/"),
                    brandColorHex: "#DA291C",
                    requiresAny: [.isCanadian]),
        CatalogItem(id: "telus", title: "TELUS", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.telus.com/"),
                    brandColorHex: "#4B286D",
                    requiresAny: [.isCanadian]),
        CatalogItem(id: "videotron", title: "Videotron", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://videotron.com/"),
                    brandColorHex: "#FFD100",
                    requires: [.isCanadian, .inQuebec]),
        CatalogItem(id: "shaw", title: "Shaw (Rogers)", emoji: "📶",
                    category: .utilities, priority: .critical, tMinusDays: -14,
                    deepLinkURL: URL(string: "https://www.shaw.ca/"),
                    brandColorHex: "#00AEEF",
                    requiresAny: [.inBritishColumbia, .inAlberta, .inManitoba, .inSaskatchewan]),
    ]

    // MARK: - ⚡ Utilities (Provincial Crown Corps & Monopolies)

    static let canadaUtilities: [CatalogItem] = [
        CatalogItem(id: "hydro_one", title: "Hydro One", emoji: "⚡",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    deepLinkURL: URL(string: "https://www.hydroone.com/"),
                    brandColorHex: "#F37021",
                    requires: [.isCanadian, .inOntario]),
        CatalogItem(id: "enbridge_gas", title: "Enbridge Gas", emoji: "🔥",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    deepLinkURL: URL(string: "https://www.enbridgegas.com/"),
                    brandColorHex: "#FFCB05",
                    requires: [.isCanadian, .inOntario]),
        CatalogItem(id: "bc_hydro", title: "BC Hydro", emoji: "⚡",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    deepLinkURL: URL(string: "https://www.bchydro.com/"),
                    brandColorHex: "#005EB8",
                    requires: [.isCanadian, .inBritishColumbia]),
        CatalogItem(id: "fortis_bc", title: "FortisBC", emoji: "🔥",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    deepLinkURL: URL(string: "https://www.fortisbc.com/"),
                    brandColorHex: "#0072CE",
                    requires: [.isCanadian, .inBritishColumbia]),
        CatalogItem(id: "hydro_quebec", title: "Hydro-Québec", emoji: "⚡",
                    category: .utilities, priority: .critical, tMinusDays: -21,
                    deepLinkURL: URL(string: "https://www.hydroquebec.com/"),
                    brandColorHex: "#F37021",
                    requires: [.isCanadian, .inQuebec]),
    ]

    // MARK: - 🛒 Retail, Loyalty & Fitness

    static let canadaRetail: [CatalogItem] = [
        CatalogItem(id: "pc_optimum", title: "PC Optimum (Shoppers / Loblaws)", emoji: "🛒",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.pcoptimum.ca/"),
                    brandColorHex: "#E31837",
                    requires: [.isCanadian]),
        CatalogItem(id: "scene_plus", title: "Scene+ (Scotiabank / Cineplex / Sobeys)", emoji: "🎬",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.sceneplus.ca/"),
                    brandColorHex: "#000000",
                    requires: [.isCanadian]),
        CatalogItem(id: "triangle_rewards", title: "Triangle Rewards (Canadian Tire)", emoji: "🔧",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://triangle.canadiantire.ca/"),
                    brandColorHex: "#E31837",
                    requires: [.isCanadian]),
        CatalogItem(id: "goodlife_fitness", title: "GoodLife Fitness", emoji: "💪",
                    category: .subscriptions, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.goodlifefitness.com/"),
                    brandColorHex: "#C41230",
                    requires: [.isCanadian]),
    ]
}
