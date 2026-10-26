import Foundation
import SwiftData

/// A single successful-save boundary for task actions from every screen.
@MainActor enum ChecklistActions {
    @discardableResult static func perform(in context: ModelContext, move: Move?,
                                           updateReminders: Bool = true,
                                           mutation: () -> Void) -> Bool {
        mutation()
        guard context.saveOrLog() else { return false }
        if updateReminders { reconcileReminders(in: context, preferred: move) }
        return true
    }

    static func activeMove(in context: ModelContext, preferred: Move? = nil) -> Move? {
        if let preferred, preferred.modelContext === context, preferred.phase == .active, !preferred.isDeleted { return preferred }
        let descriptor = FetchDescriptor<Move>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor))?.first { $0.phase == .active }
    }

    static func reconcileReminders(in context: ModelContext, preferred: Move? = nil) {
        let active = activeMove(in: context, preferred: preferred)
        SmartReminderService.shared.reschedule(for: active)
        LocationManager.shared.attach(active, context: context)
    }

    @discardableResult static func complete(_ task: ChecklistTask, in context: ModelContext) -> Bool {
        perform(in: context, move: task.move) {
            task.advanceStatus()
            if task.status == .pendingVerification { task.advanceStatus() }
        }
    }

    @discardableResult static func reopen(_ task: ChecklistTask, in context: ModelContext) -> Bool {
        perform(in: context, move: task.move) {
            task.resetStatus()
            task.isMuted = false
            task.snoozedUntil = nil
            task.move?.completionCelebratedAt = nil
        }
    }

    @discardableResult static func remove(_ task: ChecklistTask, from move: Move,
                                          in context: ModelContext) -> Bool {
        perform(in: context, move: move) {
            MoveChecklistService.recordDismissal(task, for: move)
            move.tasks.removeAll { $0.id == task.id }
            context.delete(task)
        }
    }
}
