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
    
    // Agentic & Location fields
    var actionTypeRaw: String = "Manual Deep Link"
    var poiCategoryRaw: String?

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
