import Foundation
import UserNotifications
import SwiftData
import UIKit

@MainActor enum NotificationTaskAction {
    /// Shared with tests; only an existing open task may be snoozed or muted.
    static func apply(_ action: String, to task: ChecklistTask, now: Date = Date()) -> Bool {
        guard task.status == .toDo else { return false }
        switch action {
        case "SNOOZE":
            guard !task.isMuted else { return false }
            task.snoozedUntil = now.addingTimeInterval(86400)
        case "MUTE": task.isMuted = true
        case "UNMUTE": task.isMuted = false
        case "CLEAR_SNOOZE": task.snoozedUntil = nil
        default: return false
        }
        return true
    }

    /// Restore only the reminder fields when storage fails. A failed notification
    /// action must never leave an unsaved mute/snooze affecting the running app.
    @discardableResult
    static func applyAndSave(_ action: String, to task: ChecklistTask, now: Date = Date(),
                             save: () throws -> Void) throws -> Bool {
        let muted = task.isMuted, snoozed = task.snoozedUntil
        guard apply(action, to: task, now: now) else { return false }
        do { try save(); return true }
        catch {
            task.isMuted = muted
            task.snoozedUntil = snoozed
            throw error
        }
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    let modelContainer: ModelContainer
    init(container: ModelContainer) { modelContainer = container; super.init() }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            defer { completionHandler() }
            let info = response.notification.request.content.userInfo
            if LocationConsentRenewal.owns(response.notification.request.identifier) {
                guard response.actionIdentifier == UNNotificationDefaultActionIdentifier
                        || response.actionIdentifier == LocationConsentRenewal.reviewActionIdentifier,
                      let raw = info["moveID"] as? String, let id = UUID(uuidString: raw),
                      let move = try? modelContainer.mainContext.fetch(FetchDescriptor<Move>(predicate: #Predicate { $0.id == id })).first,
                      LocationConsentRenewal.isRelevant(response.notification.request, for: move) else { return }
                NotificationRouter.shared.pendingRemindersMoveID = move.id
                return
            }
            if info["action"] as? String == "openDashboard" || response.actionIdentifier == "REVIEW_NOW" { return }
            guard let raw = info["taskID"] as? String, let id = UUID(uuidString: raw),
                  let task = try? modelContainer.mainContext.fetch(FetchDescriptor<ChecklistTask>(predicate: #Predicate { $0.id == id })).first,
                  let move = task.move, move.phase == .active,
                  (info["moveID"] as? String).map({ $0 == move.id.uuidString }) ?? true else { return }
            switch response.actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                NotificationRouter.shared.pendingTaskID = task.id
            case "UPDATE_NOW":
                if ReminderPolicy.isEligible(task), let url = CatalogGuidance.actionURL(for: task, move: move) {
                    await UIApplication.shared.open(url)
                } else { NotificationRouter.shared.pendingTaskID = task.id }
            case "SNOOZE", "MUTE":
                do {
                    guard try NotificationTaskAction.applyAndSave(response.actionIdentifier, to: task,
                        save: { try modelContainer.mainContext.save() }) else { return }
                } catch {
                    PersistenceIssueCenter.shared.report(error)
                    return
                }
                LocationManager.shared.attach(move, context: modelContainer.mainContext)
                SmartReminderService.shared.reschedule(for: move)
                await SmartReminderService.shared.waitForSchedule()
            default: break
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            let info = notification.request.content.userInfo
            if LocationConsentRenewal.owns(notification.request.identifier) {
                let moves = (try? modelContainer.mainContext.fetch(FetchDescriptor<Move>())) ?? []
                let relevant = moves.contains { LocationConsentRenewal.isRelevant(notification.request, for: $0) }
                completionHandler(relevant ? [.banner, .sound, .badge] : [])
                return
            }
            let ids = (info["taskIDs"] as? [String]) ?? (info["taskID"] as? String).map { [$0] } ?? []
            let tasks = (try? modelContainer.mainContext.fetch(FetchDescriptor<ChecklistTask>())) ?? []
            let eligible = Set(tasks.filter { $0.move?.phase == .active && ReminderPolicy.isEligible($0) }.map { $0.id.uuidString })
            let relevant = !ids.isEmpty && Set(ids).isSubset(of: eligible)
            completionHandler(relevant ? [.banner, .sound, .badge] : [])
        }
    }
}
