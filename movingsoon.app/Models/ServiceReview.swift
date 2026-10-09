import Foundation

enum ServiceDecision: String, Codable {
    case confirmed, notApplicable, unsure
}

struct ServiceResponse: Codable {
    var decision: ServiceDecision
    var updatedAt: Date
}

/// Explicit service-use answers have a different meaning from task applicability.
/// Never derive these labels from adding, completing, or dismissing a checklist item.
enum ServiceUseAnswer: String, Codable, CaseIterable {
    case usesService, doesNotUse, unsure
}

struct ServiceUseResponse: Codable {
    let answer: ServiceUseAnswer
    let answeredAt: Date
    let questionVersion: String
}

enum ReviewFamily: String, CaseIterable, Codable, Identifiable {
    case identity, money, home, insurance, family, healthPets, shopping, memberships, travel, work
    var id: String { rawValue }
    var title: String {
        switch self {
        case .identity: return "Mail & identity"
        case .money: return "Banks & payments"
        case .home: return "Home & utilities"
        case .insurance: return "Insurance"
        case .family: return "Children & education"
        case .healthPets: return "Health & pets"
        case .shopping: return "Shopping & subscriptions"
        case .memberships: return "Memberships & community"
        case .travel: return "Vehicles & travel"
        case .work: return "Work & legal"
        }
    }
    var emoji: String {
        switch self {
        case .identity: return "📬"
        case .money: return "🏦"
        case .home: return "🏠"
        case .insurance: return "🛡️"
        case .family: return "🧒"
        case .healthPets: return "🐾"
        case .shopping: return "📦"
        case .memberships: return "🎟️"
        case .travel: return "🚗"
        case .work: return "💼"
        }
    }
}

enum HouseholdAnswer: String, CaseIterable, Identifiable {
    case unknown, yes, no
    var id: String { rawValue }
    var title: String { self == .unknown ? "Skip for now" : (self == .yes ? "Yes" : "No") }
    var value: Bool? { self == .unknown ? nil : self == .yes }
    init(_ value: Bool?) { self = value.map { $0 ? .yes : .no } ?? .unknown }
}

enum HousingArrangement: String, CaseIterable, Identifiable {
    case unknown, rent, own, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .unknown: return "Skip for now"
        case .rent: return "Renting"
        case .own: return "Owning"
        case .other: return "Other arrangement"
        }
    }
}

enum HomeKind: String, CaseIterable, Identifiable {
    case unknown, house, apartment, condo, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .unknown: return "Skip for now"
        case .house: return "House / townhouse"
        case .apartment: return "Apartment"
        case .condo: return "Condo"
        case .other: return "Other"
        }
    }
}

enum ServiceMoveAction: String, Codable {
    case updateAddress, reviewTransfer, closeOldService, startNewService, reviewRequirements
    var title: String {
        switch self {
        case .updateAddress: return "Update your address"
        case .reviewTransfer: return "Check transfer or cancellation"
        case .closeOldService: return "Close out the previous home"
        case .startNewService: return "Arrange service at the new home"
        case .reviewRequirements: return "Check what this move changes"
        }
    }
}

enum DiscoveryContext: String {
    case children, pets, vehicle, housing, work, transition
}
