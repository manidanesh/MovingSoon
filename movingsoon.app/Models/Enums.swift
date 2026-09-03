// Enums.swift — All domain enumerations
import Foundation
import SwiftUI

// MARK: - Persona

enum PersonaKey: String, Codable, CaseIterable {
    case collegeGrad         = "College Grad"
    case youngCouple         = "Young Couple"
    case familyWithKids      = "Family with Kids"
    case divorceSeparation   = "Divorce / Separation"
    case activeProfessional  = "Active Professional"
    case retiree             = "Retiree / Senior"

    var displayName: String { rawValue }

    var tagline: String {
        switch self {
        case .collegeGrad:        return "Starting fresh 🎓"
        case .youngCouple:        return "Moving together 💛"
        case .familyWithKids:     return "You've got this 🏡"
        case .divorceSeparation:  return "One step at a time."
        case .activeProfessional: return "Let's get it done ⚡"
        case .retiree:            return "We'll guide you through it 🌿"
        }
    }
}

// MARK: - Task

enum TaskStatus: String, Codable, CaseIterable {
    case toDo                = "To Do"
    case pendingVerification = "Pending"
    case completed           = "Completed"
}

enum TaskPriority: String, Codable, CaseIterable, Comparable {
    case critical = "Critical"
    case high     = "High"
    case medium   = "Medium"
    case low      = "Low"

    private var sortIndex: Int {
        switch self { case .critical: return 0; case .high: return 1; case .medium: return 2; case .low: return 3 }
    }
    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool { lhs.sortIndex < rhs.sortIndex }

    var bucketLabel: String {
        switch self {
        case .critical: return "Critical — Do Now"
        case .high:     return "High Priority"
        case .medium:   return "First Two Weeks"
        case .low:      return "When You're Settled"
        }
    }

    var color: Color {
        switch self {
        case .critical: return Theme.priorityCritical
        case .high:     return Theme.priorityHigh
        case .medium:   return Theme.priorityMedium
        case .low:      return Theme.priorityLow
        }
    }
}

enum TaskCategory: String, Codable, CaseIterable {
    case postal        = "Postal"
    case government    = "Government"
    case financial     = "Financial"
    case utilities     = "Utilities"
    case subscriptions = "Subscriptions"
    case healthcare    = "Healthcare"
    case education     = "Education"
    case insurance     = "Insurance"
    case legal         = "Legal"
    case employer      = "Employer"
    case travel        = "Travel & Loyalty"
    case estate        = "Estate & Legal Planning"
    case digital       = "Digital Identity"
    case other         = "Other"

    var icon: String {
        switch self {
        case .postal:        return "envelope.fill"
        case .government:    return "building.columns.fill"
        case .financial:     return "creditcard.fill"
        case .utilities:     return "bolt.fill"
        case .subscriptions: return "arrow.clockwise.circle.fill"
        case .healthcare:    return "cross.fill"
        case .education:     return "graduationcap.fill"
        case .insurance:     return "shield.fill"
        case .legal:         return "doc.text.fill"
        case .employer:      return "briefcase.fill"
        case .travel:        return "airplane"
        case .estate:        return "scroll.fill"
        case .digital:       return "globe"
        case .other:         return "ellipsis.circle.fill"
        }
    }

    /// One deliberate hue per category (top/bottom of a gradient) — not one repeated
    /// color. Home Screen icons are scannable specifically because every app has a
    /// distinct color; making every category tile the same gradient would work
    /// against that reference, forcing users to read the glyph alone to tell
    /// categories apart. Semantically anchored where a mapping exists unforced
    /// (green for Financial, rose for Healthcare, amber for Utilities — echoing
    /// Theme.accentWarning's "due soon" amber), spread hue-wise elsewhere so no two
    /// categories collide. Severity/urgency lives at the section header, not here —
    /// this palette is purely for category identity.
    var iconGradient: (top: Color, bottom: Color) {
        switch self {
        case .postal:        return (Color(hex: "#3B82F6"), Color(hex: "#1E3A8A"))  // blue
        case .government:    return (Color(hex: "#6366F1"), Color(hex: "#3730A3"))  // indigo
        case .financial:     return (Color(hex: "#22C55E"), Color(hex: "#15803D"))  // green
        case .utilities:     return (Color(hex: "#F59E0B"), Color(hex: "#B45309"))  // amber
        case .subscriptions: return (Color(hex: "#D946EF"), Color(hex: "#86198F"))  // magenta
        case .healthcare:    return (Color(hex: "#FB7185"), Color(hex: "#9F1239"))  // rose
        case .education:     return (Color(hex: "#22D3EE"), Color(hex: "#0E7490"))  // cyan
        case .insurance:     return (Color(hex: "#14B8A6"), Color(hex: "#0F766E"))  // teal
        case .legal:         return (Color(hex: "#64748B"), Color(hex: "#334155"))  // slate
        case .employer:      return (Color(hex: "#FB923C"), Color(hex: "#C2410C"))  // orange
        case .travel:        return (Color(hex: "#0EA5E9"), Color(hex: "#075985"))  // sky
        case .estate:        return (Color(hex: "#A8A29E"), Color(hex: "#57534E"))  // warm stone
        case .digital:       return (Color(hex: "#8B5CF6"), Color(hex: "#5B21B6"))  // violet
        case .other:         return (Color(hex: "#9CA3AF"), Color(hex: "#4B5563"))  // neutral gray
        }
    }

    var emoji: String {
        switch self {
        case .postal:        return "📬"
        case .government:    return "🏛️"
        case .financial:     return "💳"
        case .utilities:     return "⚡"
        case .subscriptions: return "🔄"
        case .healthcare:    return "🏥"
        case .education:     return "🎓"
        case .insurance:     return "🛡️"
        case .legal:         return "📄"
        case .employer:      return "💼"
        case .travel:        return "✈️"
        case .estate:        return "📜"
        case .digital:       return "🌐"
        case .other:         return "📌"
        }
    }
}

// MARK: - Task Subcategory

enum TaskSubcategory: String, Codable, CaseIterable {
    // Postal
    case mailForwarding       = "Mail Forwarding"
    // Government
    case federalID            = "Federal Identification"
    case taxCivic             = "Tax & Civic"
    case benefitsPrograms     = "Benefits & Programs"
    case travelSecurity       = "Travel & Security Programs"
    // Financial
    case everydayBanking      = "Everyday Banking"
    case creditLending        = "Credit & Lending"
    case investmentsWealth    = "Investments & Wealth"
    case digitalPayments      = "Digital Payments"
    // Insurance
    case vehicleInsurance     = "Vehicle Insurance"
    case propertyInsurance    = "Property Insurance"
    case healthLifeInsurance  = "Health & Life Insurance"
    case specialtyInsurance   = "Specialty Protection"
    // Housing
    case coreUtilities        = "Core Utilities"
    case telecomConnectivity  = "Telecom & Connectivity"
    case smartHomeOps         = "Smart Home & Security"
    case homeServices         = "Recurring Home Services"
    // Shopping
    case appStoresEcosystems  = "App Stores & Ecosystems"
    case ecommerceWholesale   = "E-Commerce & Wholesale"
    case subscriptionBoxes    = "Subscription Boxes & Clubs"
    case onDemandDelivery     = "On-Demand Delivery"
    case mealKits             = "Meal Kits"
    case newsMagazines        = "News & Magazines"
    // Travel
    case airlineLoyalty       = "Airline Loyalty Programs"
    case hotelLoyalty         = "Hotel Loyalty Programs"
    case rentalCarPrograms    = "Rental Car Programs"
    case transitCommuting     = "Transit & Commuting"
    case vehiclePrograms      = "Auto Programs"
    // Health
    case medicalPractitioners = "Medical Practitioners"
    case pharmacyRx           = "Pharmacy & Prescriptions"
    case animalCare           = "Veterinary & Animal Care"
    case pediatricFamily      = "Pediatrics & Family"
    // Employer & Education
    case careerPayroll        = "Career & Payroll"
    case professionalLicenses = "Professional Licensing"
    case businessOps          = "Business Operations"
    case selfEducation        = "Education (Self)"
    case kidsEducation        = "Education (Kids)"
    // Estate & Legal
    case estatePlanning       = "Estate Planning Documents"
    case beneficiaries        = "Beneficiary Designations"
    case legalRecords         = "Legal Records & Storage"
    // Digital Identity
    case browserDevice        = "Browser & Device AutoFill"
    case socialMedia          = "Social Media & Maps"
    case onlineDirectories    = "Online Directories"
    case domainHosting        = "Domain & Hosting"
    // Lifestyle
    case fitnessWellness      = "Fitness & Wellness"
    case socialCommunity      = "Community & Faith"
    case charityPhilanthropy  = "Charity & Philanthropy"
    case other                = "Other"
}

enum VerificationMethod: String, Codable {
    case emailScan     = "Email Scan"
    case manualConfirm = "Manual Confirm"
    case deepLink      = "Deep Link"
    case siriIntent    = "Siri Intent"
}

enum ActionType: String, Codable, CaseIterable {
    case manualDeepLink = "Manual Deep Link"
    case agenticUpdate  = "Agentic Update"
}

enum POICategory: String, Codable, CaseIterable {
    case bank          = "Bank"
    case gym           = "Gym"
    case dmv           = "DMV"
    case grocery       = "Grocery"
    case postOffice    = "Post Office"
    case pharmacy      = "Pharmacy"
    case bookstore     = "Bookstore"
    case outdoorGear   = "Outdoor Gear"
    case hardwareStore = "Hardware Store"
    case doctor        = "Doctor's Office"
    case airport       = "Airport"
    case hotel         = "Hotel"
    case rentalCar     = "Rental Car Agency"
    case autoRepair    = "Auto Repair Shop"
    case other         = "Other"

    var displayName: String {
        switch self {
        case .bank:          return "bank"
        case .gym:           return "gym"
        case .dmv:           return "DMV"
        case .grocery:       return "grocery store"
        case .postOffice:    return "post office"
        case .pharmacy:      return "pharmacy"
        case .bookstore:     return "bookstore"
        case .outdoorGear:   return "outdoor gear store"
        case .hardwareStore: return "hardware store"
        case .doctor:        return "doctor's office"
        case .airport:       return "airport"
        case .hotel:         return "hotel"
        case .rentalCar:     return "rental car agency"
        case .autoRepair:    return "auto repair shop"
        case .other:         return "location"
        }
    }
}

// MARK: - Move

enum MoveType: String, Codable, CaseIterable {
    case rent           = "Renting"
    case buy            = "Buying / Owned"
    case careTransition = "Moving to Care"
}

enum HouseholdType: String, Codable, CaseIterable {
    case solo    = "Just Me"
    case partner = "Me & My Partner"
    case family  = "Family"
}

enum CustodyType: String, Codable, CaseIterable {
    case primary   = "Primary Custody"
    case shared    = "Shared Custody"
    case none      = "No Arrangement"
}

enum WorkStatus: String, Codable, CaseIterable {
    case employed      = "Employed"
    case selfEmployed  = "Self-Employed"
    case retired       = "Retired"
    case student       = "Student"
    case notWorking    = "Not Currently Working"
}

enum CatalystType: String, Codable, CaseIterable {
    case newJob          = "New job or opportunity"
    case changeOfScenery = "Change of scenery"
    case recentLifeChange = "A recent life change"
}

enum MovePhase: String, Codable {
    case active   = "Active"
    case archived = "Archived"
}
