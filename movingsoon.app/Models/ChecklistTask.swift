// ChecklistTask.swift — SwiftData model for an individual checklist item
import Foundation
import SwiftData

@Model
final class ChecklistTask {
    var id: UUID
    var title: String
    var categoryRaw: String
    var priorityRaw: String
    var tMinusDays: Int          // negative = before anchor date
    var statusRaw: String
    var isUserAdded: Bool
    var isHeroItem: Bool
    var deepLinkURLString: String?
    var assignee: String?        // parked — Phase 2
    var signalEmitted: Bool
    /// Optional additive fields keep existing stores readable. Titles are display copy,
    /// while catalog IDs preserve the customer's decisions across catalog updates.
    var catalogItemID: String?
    var moveActionRaw: String?
    var customerNote: String?
    var needsLocationReview: Bool?
    /// One task UUID identifies one account; several accounts may share a catalog ID.
    var accountProviderName: String?
    var accountNickname: String?
    var accountBaseTitle: String?
    var nextShipmentDate: Date?
    var nextRenewalDate: Date?
    var accountReminderLeadDays: Int?
    var absoluteDueDate: Date?
    
    // Agentic & Location fields
    var actionTypeRaw: String = "Manual Deep Link"
    var poiCategoryRaw: String?
    var isMuted: Bool = false
    var snoozedUntil: Date?

    // Institution identity (nil for non-financial tasks)
    var institutionName: String?
    var institutionInitials: String?
    var institutionColorHex: String?

    @Relationship(deleteRule: .cascade)
    var verificationEvents: [VerificationEvent]

    var move: Move?

    init(
        title: String,
        category: TaskCategory,
        priority: TaskPriority,
        tMinusDays: Int,
        isHeroItem: Bool = false,
        deepLinkURL: URL? = nil,
        isUserAdded: Bool = false
    ) {
        self.id                  = UUID()
        self.title               = title
        self.categoryRaw         = category.rawValue
        self.priorityRaw         = priority.rawValue
        self.tMinusDays          = tMinusDays
        self.statusRaw           = TaskStatus.toDo.rawValue
        self.isUserAdded         = isUserAdded
        self.isHeroItem          = isHeroItem
        self.deepLinkURLString   = deepLinkURL?.absoluteString
        self.assignee            = nil
        self.signalEmitted       = false
        self.actionTypeRaw       = ActionType.manualDeepLink.rawValue
        self.poiCategoryRaw      = nil
        self.isMuted             = false
        self.snoozedUntil        = nil
        self.institutionName     = nil
        self.institutionInitials = nil
        self.institutionColorHex = nil
        self.verificationEvents  = []
    }

    // MARK: - Computed

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .toDo }
        set { statusRaw = newValue.rawValue }
    }

    var priority: TaskPriority {
        TaskPriority(rawValue: priorityRaw) ?? .medium
    }

    var category: TaskCategory {
        TaskCategory(rawValue: categoryRaw) ?? .other
    }

    var deepLinkURL: URL? {
        guard let str = deepLinkURLString else { return nil }
        return URL(string: str)
    }

    var moveAction: ServiceMoveAction {
        moveActionRaw.flatMap(ServiceMoveAction.init(rawValue:)) ?? .updateAddress
    }

    var reminderLeadDays: Int { min(30, max(0, accountReminderLeadDays ?? 3)) }

    var hasAccountDetails: Bool {
        accountBaseTitle != nil || accountProviderName != nil || accountNickname != nil
            || nextShipmentDate != nil || nextRenewalDate != nil
    }

    func baseDueDate(moveDate: Date, calendar: Calendar = .current) -> Date {
        if let absoluteDueDate { return calendar.startOfDay(for: absoluteDueDate) }
        return calendar.date(byAdding: .day, value: tMinusDays, to: calendar.startOfDay(for: moveDate)) ?? moveDate
    }

    /// A customer-entered shipment/renewal can bring the address review forward.
    /// Event dates stay absolute when moving day changes.
    func dueDate(moveDate: Date, calendar: Calendar = .current) -> Date {
        let deadlines = [nextShipmentDate, nextRenewalDate].compactMap { date -> Date? in
            guard let date else { return nil }
            return calendar.date(byAdding: .day, value: -reminderLeadDays, to: calendar.startOfDay(for: date))
        }
        return ([baseDueDate(moveDate: moveDate, calendar: calendar)] + deadlines).min() ?? moveDate
    }

    func isDueBefore(_ other: ChecklistTask, moveDate: Date, calendar: Calendar = .current) -> Bool {
        let mine = dueDate(moveDate: moveDate, calendar: calendar)
        let theirs = other.dueDate(moveDate: moveDate, calendar: calendar)
        return mine == theirs ? id.uuidString < other.id.uuidString : mine < theirs
    }

    func daysUntilDue(moveDate: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                to: dueDate(moveDate: moveDate, calendar: calendar)).day ?? 0
    }

    var actionType: ActionType {
        get { ActionType(rawValue: actionTypeRaw) ?? .manualDeepLink }
        set { actionTypeRaw = newValue.rawValue }
    }

    var poiCategory: POICategory? {
        get {
            guard let raw = poiCategoryRaw else { return nil }
            return POICategory(rawValue: raw)
        }
        set { poiCategoryRaw = newValue?.rawValue }
    }

    // MARK: - State machine

    /// Advances toDo → pendingVerification → completed
    func advanceStatus(method: VerificationMethod = .manualConfirm) {
        switch status {
        case .toDo:
            status = .pendingVerification
        case .pendingVerification:
            status = .completed
            let event = VerificationEvent(method: method)
            verificationEvents.append(event)
        case .completed:
            break
        }
    }

    /// Resets back to toDo (undo support)
    func resetStatus() {
        status = .toDo
        verificationEvents.removeAll()
    }
}
