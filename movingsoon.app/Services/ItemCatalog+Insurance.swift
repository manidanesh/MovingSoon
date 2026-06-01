// ItemCatalog+Insurance.swift — Insurance subcategories: Vehicle, Property, Health/Life, Specialty
import Foundation

extension ItemCatalog {

    static var allInsurance: [CatalogItem] {
        vehicleInsurance + propertyInsurance + healthLifeInsurance + specialtyInsurance
    }

    // MARK: - 🚗 Vehicle Insurance

    static let vehicleInsurance: [CatalogItem] = [
        CatalogItem(id: "auto_insurance_update", title: "Auto Insurance — Update Address", emoji: "🚗",
                    category: .insurance, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#E74C3C",
                    requiresAny: [.hasCar, .hasAutoInsurance, .hasElectricVehicle]),
        CatalogItem(id: "motorcycle_insurance", title: "Motorcycle Insurance — Update Address", emoji: "🏍️",
                    category: .insurance, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#C0392B",
                    requiresAny: [.hasMotorcycle, .hasMotorcycleInsurance]),
        CatalogItem(id: "rv_insurance", title: "RV / Camper Insurance — Update Address", emoji: "🚌",
                    category: .insurance, priority: .high, tMinusDays: -7,
                    brandColorHex: "#E67E22",
                    requires: [.hasRVInsurance]),
        CatalogItem(id: "boat_insurance", title: "Boat / Watercraft Insurance — Update Address", emoji: "⛵",
                    category: .insurance, priority: .high, tMinusDays: -7,
                    brandColorHex: "#2E86C1",
                    requires: [.hasBoatInsurance]),
    ]

    // MARK: - 🏠 Property Insurance

    static let propertyInsurance: [CatalogItem] = [
        CatalogItem(id: "homeowners_insurance", title: "Homeowner's Insurance — Update Address", emoji: "🏡",
                    category: .insurance, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#C0392B",
                    requiresAny: [.isOwning, .hasHomeownersInsurance]),
        CatalogItem(id: "renters_insurance_update", title: "Renter's Insurance — Activate at New Address", emoji: "🏠",
                    category: .insurance, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#117ACA",
                    requiresAny: [.isRenting, .hasRentersInsurance]),
        CatalogItem(id: "condo_insurance", title: "Condo / Strata Insurance — Update Address", emoji: "🏢",
                    category: .insurance, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#8E44AD",
                    requires: [.hasCondoInsurance]),
        CatalogItem(id: "landlord_insurance", title: "Landlord / Rental Property Insurance", emoji: "🏘️",
                    category: .insurance, priority: .high, tMinusDays: -7,
                    brandColorHex: "#1B4F72",
                    requiresAny: [.hasLandlordInsurance, .hasRentalProperty]),
        CatalogItem(id: "umbrella_policy", title: "Umbrella Policy — Update Address", emoji: "☂️",
                    category: .insurance, priority: .medium, tMinusDays: -7,
                    brandColorHex: "#5D6D7E",
                    requires: [.hasUmbrellaInsurance]),
    ]

    // MARK: - 🛡️ Health & Life Insurance

    static let healthLifeInsurance: [CatalogItem] = [
        CatalogItem(id: "health_insurance_update", title: "Health Insurance — Update Address", emoji: "🛡️",
                    category: .insurance, priority: .critical, tMinusDays: -14,
                    brandColorHex: "#1A5276", alwaysInclude: true),
        CatalogItem(id: "dental_vision_insurance", title: "Dental & Vision Insurance — Update Address", emoji: "🦷",
                    category: .insurance, priority: .high, tMinusDays: -7,
                    brandColorHex: "#2E86C1", alwaysInclude: true),
        CatalogItem(id: "life_insurance_update", title: "Life Insurance — Update Address", emoji: "📋",
                    category: .insurance, priority: .high, tMinusDays: -7,
                    brandColorHex: "#212F3D",
                    requires: [.hasLifeInsurance]),
        CatalogItem(id: "disability_insurance", title: "Short/Long-Term Disability Insurance", emoji: "🩺",
                    category: .insurance, priority: .medium, tMinusDays: -7,
                    brandColorHex: "#7D3C98",
                    requires: [.hasDisabilityInsurance]),
        CatalogItem(id: "fsa_hsa_update", title: "FSA / HSA Account — Update Address", emoji: "🏦",
                    category: .insurance, priority: .high, tMinusDays: 7,
                    brandColorHex: "#8E44AD",
                    requires: [.hasFSA]),
    ]

    // MARK: - 🔮 Specialty Insurance & Protection

    static let specialtyInsurance: [CatalogItem] = [
        CatalogItem(id: "pet_insurance_update", title: "Pet Insurance — Update Address", emoji: "🐾",
                    category: .insurance, priority: .high, tMinusDays: -7,
                    brandColorHex: "#2E86C1",
                    requires: [.hasPetInsurance]),
        CatalogItem(id: "jewelry_insurance", title: "Jewelry / Art / Collectibles Insurance", emoji: "💎",
                    category: .insurance, priority: .medium, tMinusDays: 7,
                    brandColorHex: "#9B59B6",
                    requires: [.hasJewelryInsurance]),
        CatalogItem(id: "id_theft_protection", title: "ID Theft Protection (LifeLock / Aura)", emoji: "🔒",
                    category: .insurance, priority: .medium, tMinusDays: 0,
                    deepLinkURL: URL(string: "https://www.lifelock.com/account"),
                    brandColorHex: "#D35400",
                    requires: [.hasIDTheftProtection]),
        CatalogItem(id: "appliance_home_warranty", title: "Appliance & Home Warranty — Update Address", emoji: "🛠️",
                    category: .insurance, priority: .medium, tMinusDays: 7,
                    brandColorHex: "#34495E",
                    requires: [.hasHomeWarranties]),
        CatalogItem(id: "vehicle_warranty_update", title: "Vehicle Extended Warranty — Update Address", emoji: "🚘",
                    category: .insurance, priority: .medium, tMinusDays: 7,
                    brandColorHex: "#E74C3C",
                    requires: [.hasVehicleWarranty]),
    ]
}
