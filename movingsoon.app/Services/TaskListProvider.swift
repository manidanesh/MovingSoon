// TaskListProvider.swift — Static MVP task lists for Phase 1 personas
import Foundation

enum TaskListProvider {

    static let uspsHeroURL = URL(string: "https://moversguide.usps.com/")!

    // MARK: - Institution-specific task generation

    static func institutionTasks(for institutions: [KnownInstitution]) -> [ChecklistTask] {
        institutions.map { institution in
            let task = ChecklistTask(
                title: "Update address with \(institution.name)",
                category: categoryFor(institution.type),
                priority: priorityFor(institution.type),
                tMinusDays: tMinusFor(institution.type),
                deepLinkURL: institution.websiteURL
            )
            task.institutionName     = institution.name
            task.institutionInitials = institution.initials
            task.institutionColorHex = institution.colorHex
            return task
        }
    }

    private static func categoryFor(_ type: InstitutionType) -> TaskCategory {
        switch type {
        case .bank, .creditUnion: return .financial
        case .creditCard:         return .financial
        case .investment:         return .financial
        case .studentLoan:        return .education
        case .mortgage:           return .financial
        }
    }

    private static func priorityFor(_ type: InstitutionType) -> TaskPriority {
        switch type {
        case .bank, .creditUnion: return .critical
        case .mortgage:           return .critical
        case .creditCard:         return .high
        case .investment:         return .high
        case .studentLoan:        return .high
        }
    }

    private static func tMinusFor(_ type: InstitutionType) -> Int {
        switch type {
        case .bank, .creditUnion, .mortgage: return -14
        case .creditCard, .studentLoan:      return -7
        case .investment:                    return 7
        }
    }

    // MARK: - Public entry point

    static func tasks(for persona: PersonaKey) -> [ChecklistTask] {
        var list: [ChecklistTask] = [heroUSPS]
        switch persona {
        case .collegeGrad:        list += collegeGradTasks
        case .activeProfessional: list += activeProfessionalTasks
        case .youngCouple:        list += youngCoupleTasks
        case .familyWithKids:     list += familyTasks
        case .divorceSeparation:  list += divorceTasks
        case .retiree:            list += retireeTasks
        }
        return list
    }

    // MARK: - Hero (universal)

    private static var heroUSPS: ChecklistTask {
        ChecklistTask(
            title: "Forward Your Mail — USPS",
            category: .postal,
            priority: .critical,
            tMinusDays: -28,
            isHeroItem: true,
            deepLinkURL: uspsHeroURL
        )
    }

    // MARK: - College Grad (14 items)

    private static var collegeGradTasks: [ChecklistTask] {[
        ChecklistTask(title: "Update Driver's License / State ID", category: .government, priority: .critical, tMinusDays: -14),
        ChecklistTask(title: "Update Vehicle Registration", category: .government, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update Voter Registration", category: .government, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Notify Student Loan Servicer", category: .financial, priority: .critical, tMinusDays: -14,
                      deepLinkURL: URL(string: "https://studentaid.gov/")),
        ChecklistTask(title: "Update University Registrar / Alumni Office", category: .education, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update Bank / Checking Account", category: .financial, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update Credit Cards", category: .financial, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update Health Insurance", category: .healthcare, priority: .critical, tMinusDays: -14),
        ChecklistTask(title: "Transfer Medical Records", category: .healthcare, priority: .medium, tMinusDays: 7),
        ChecklistTask(title: "Update Streaming & Subscriptions", category: .subscriptions, priority: .low, tMinusDays: 14),
        ChecklistTask(title: "Update Amazon & Online Shopping", category: .subscriptions, priority: .medium, tMinusDays: 7),
        ChecklistTask(title: "Notify Employer / HR", category: .employer, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update Parents & Emergency Contacts", category: .other, priority: .medium, tMinusDays: 0),
    ]}

    // MARK: - Active Professional (22 items)

    private static var activeProfessionalTasks: [ChecklistTask] {[
        ChecklistTask(title: "Update Driver's License / State ID", category: .government, priority: .critical, tMinusDays: -14),
        ChecklistTask(title: "Update Vehicle Registration", category: .government, priority: .critical, tMinusDays: -14),
        ChecklistTask(title: "Update Voter Registration", category: .government, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Notify Employer / HR — Payroll Update", category: .employer, priority: .critical, tMinusDays: -14),
        ChecklistTask(title: "Update Primary Bank Account", category: .financial, priority: .critical, tMinusDays: -14),
        ChecklistTask(title: "Update Investment Accounts (401k, Brokerage)", category: .financial, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update All Credit Cards", category: .financial, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update Health Insurance / Benefits", category: .healthcare, priority: .critical, tMinusDays: -14),
        ChecklistTask(title: "Update Dental & Vision Insurance", category: .insurance, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update Life Insurance", category: .insurance, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update Auto Insurance", category: .insurance, priority: .critical, tMinusDays: -14),
        ChecklistTask(title: "Update Homeowner / Renter's Insurance", category: .insurance, priority: .critical, tMinusDays: -14),
        ChecklistTask(title: "Transfer Primary Care Physician Records", category: .healthcare, priority: .medium, tMinusDays: 7),
        ChecklistTask(title: "Transfer Dentist Records", category: .healthcare, priority: .medium, tMinusDays: 14),
        ChecklistTask(title: "Transfer Pharmacy Prescriptions", category: .healthcare, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update Streaming & Software Subscriptions", category: .subscriptions, priority: .low, tMinusDays: 14),
        ChecklistTask(title: "Update Amazon & Online Shopping", category: .subscriptions, priority: .medium, tMinusDays: 7),
        ChecklistTask(title: "Update Professional Licenses / Certifications", category: .legal, priority: .high, tMinusDays: -7),
        ChecklistTask(title: "Update Apple Wallet & Payment Methods", category: .financial, priority: .medium, tMinusDays: 7),
        ChecklistTask(title: "Update LinkedIn & Professional Profiles", category: .other, priority: .low, tMinusDays: 21),
        ChecklistTask(title: "Cancel or Transfer PO Box / Mailbox Service", category: .postal, priority: .medium, tMinusDays: -7),
    ]}

    // MARK: - Young Couple (26 items — stub for Phase 2)

    private static var youngCoupleTasks: [ChecklistTask] { activeProfessionalTasks }

    // MARK: - Family with Kids (47 items — stub for Phase 2)

    private static var familyTasks: [ChecklistTask] { activeProfessionalTasks }

    // MARK: - Divorce / Separation (38 items — stub for Phase 2)

    private static var divorceTasks: [ChecklistTask] { activeProfessionalTasks }

    // MARK: - Retiree (31 items — stub for Phase 2)

    private static var retireeTasks: [ChecklistTask] { collegeGradTasks }
}
