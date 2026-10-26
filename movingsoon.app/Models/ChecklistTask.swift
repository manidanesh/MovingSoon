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
    var nextShipmentDateOnly: String?
    var nextRenewalDateOnly: String?
    var accountReminderLeadDays: Int?
    var absoluteDueDate: Date?
    var absoluteDueDateOnly: String?
    
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
            || nextShipmentDateOnly != nil || nextRenewalDateOnly != nil
    }

    var effectiveNextShipmentDate: Date? { shipmentDate() }
    var effectiveNextRenewalDate: Date? { renewalDate() }

    func shipmentDate(calendar: Calendar = .current) -> Date? {
        DateOnly.resolve(nextShipmentDateOnly, legacy: nextShipmentDate, calendar: calendar)
    }

    func renewalDate(calendar: Calendar = .current) -> Date? {
        DateOnly.resolve(nextRenewalDateOnly, legacy: nextRenewalDate, calendar: calendar)
    }

    func customDueDate(calendar: Calendar = .current) -> Date? {
        DateOnly.resolve(absoluteDueDateOnly, legacy: absoluteDueDate, calendar: calendar)
    }

    func setShipmentDate(_ date: Date?, calendar: Calendar = .current) {
        nextShipmentDateOnly = date.map { DateOnly.string(from: $0, calendar: calendar) }
        nextShipmentDate = date.map { calendar.startOfDay(for: $0) }
    }

    func setRenewalDate(_ date: Date?, calendar: Calendar = .current) {
        nextRenewalDateOnly = date.map { DateOnly.string(from: $0, calendar: calendar) }
        nextRenewalDate = date.map { calendar.startOfDay(for: $0) }
    }

    func setCustomDueDate(_ date: Date?, calendar: Calendar = .current) {
        absoluteDueDateOnly = date.map { DateOnly.string(from: $0, calendar: calendar) }
        absoluteDueDate = date.map { calendar.startOfDay(for: $0) }
    }

    /// Call once with the customer's known source timezone, when available.
    /// Without it, migration preserves the day currently displayed on this device.
    @discardableResult
    func backfillDateOnlyValues(calendar: Calendar = .current) -> Bool {
        var changed = false
        if DateOnly.date(from: nextShipmentDateOnly, calendar: calendar) == nil, let nextShipmentDate {
            nextShipmentDateOnly = DateOnly.string(from: nextShipmentDate, calendar: calendar)
            changed = true
        }
        if DateOnly.date(from: nextRenewalDateOnly, calendar: calendar) == nil, let nextRenewalDate {
            nextRenewalDateOnly = DateOnly.string(from: nextRenewalDate, calendar: calendar)
            changed = true
        }
        if DateOnly.date(from: absoluteDueDateOnly, calendar: calendar) == nil, let absoluteDueDate {
            absoluteDueDateOnly = DateOnly.string(from: absoluteDueDate, calendar: calendar)
            changed = true
        }
        return changed
    }

    func baseDueDate(moveDate: Date, calendar: Calendar = .current) -> Date {
        if let date = customDueDate(calendar: calendar) { return date }
        return calendar.date(byAdding: .day, value: tMinusDays, to: calendar.startOfDay(for: moveDate)) ?? moveDate
    }

    /// A customer-entered shipment/renewal can bring the address review forward.
    /// Event dates stay absolute when moving day changes.
    func dueDate(moveDate: Date, calendar: Calendar = .current) -> Date {
        let deadlines = [shipmentDate(calendar: calendar), renewalDate(calendar: calendar)].compactMap { date -> Date? in
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
