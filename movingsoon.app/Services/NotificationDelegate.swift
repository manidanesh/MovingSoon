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
        default: return false
        }
        return true
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
            if info["action"] as? String == "openDashboard" || response.actionIdentifier == "REVIEW_NOW" { return }
            guard let raw = info["taskID"] as? String, let id = UUID(uuidString: raw),
                  let task = try? modelContainer.mainContext.fetch(FetchDescriptor<ChecklistTask>(predicate: #Predicate { $0.id == id })).first,
                  let move = task.move, move.phase == .active,
                  (info["moveID"] as? String).map({ $0 == move.id.uuidString }) ?? true else { return }
            switch response.actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                NotificationRouter.shared.pendingTaskID = task.id
            case "UPDATE_NOW":
                if ReminderPolicy.isEligible(task), let url = task.deepLinkURL {
                    await UIApplication.shared.open(url)
                }
            case "SNOOZE", "MUTE":
                guard NotificationTaskAction.apply(response.actionIdentifier, to: task) else { return }
                do { try modelContainer.mainContext.save() } catch { return }
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
            let ids = (info["taskIDs"] as? [String]) ?? (info["taskID"] as? String).map { [$0] } ?? []
            let tasks = (try? modelContainer.mainContext.fetch(FetchDescriptor<ChecklistTask>())) ?? []
            let eligible = Set(tasks.filter { $0.move?.phase == .active && ReminderPolicy.isEligible($0) }.map { $0.id.uuidString })
            let relevant = !ids.isEmpty && Set(ids).isSubset(of: eligible)
            completionHandler(relevant ? [.banner, .sound, .badge] : [])
        }
    }
}
