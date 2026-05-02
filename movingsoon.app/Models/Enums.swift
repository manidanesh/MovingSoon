// Enums.swift — All domain enumerations
import Foundation

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
        case .other:         return "ellipsis.circle.fill"
        }
    }
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
    case bank       = "Bank"
    case gym        = "Gym"
    case dmv        = "DMV"
    case grocery    = "Grocery"
    case postOffice = "Post Office"
    case pharmacy   = "Pharmacy"
    case other      = "Other"
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
