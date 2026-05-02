// PersonaEngine.swift — Maps onboarding answers to a PersonaKey
import Foundation

enum PersonaEngine {

    struct Answers {
        var householdType: HouseholdType = .solo
        var hasChildren: Bool            = false
        var custodyType: CustodyType?    = nil
        var workStatus: WorkStatus       = .employed
        var catalyst: CatalystType       = .changeOfScenery
    }

    static func determinePersona(from answers: Answers) -> PersonaKey {

        // 1. High-stakes catalyst override
        if answers.catalyst == .recentLifeChange {
            if answers.hasChildren && answers.custodyType == .shared {
                return .divorceSeparation
            }
        }

        // 2. Work status overrides (strong signal)
        switch answers.workStatus {
        case .retired:  return .retiree
        case .student:  return .collegeGrad
        default:        break
        }

        // 3. Household composition
        switch answers.householdType {
        case .solo:
            return .activeProfessional
        case .partner:
            return .youngCouple
        case .family:
            return answers.hasChildren ? .familyWithKids : .youngCouple
        }
    }
}
