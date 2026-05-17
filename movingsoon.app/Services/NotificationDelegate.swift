// NotificationDelegate.swift — Handles actionable push notifications
import Foundation
import UserNotifications
import SwiftData

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    let modelContainer: ModelContainer
    
    init(container: ModelContainer) {
        self.modelContainer = container
        super.init()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let taskIDString = userInfo["taskID"] as? String,
              let taskID = UUID(uuidString: taskIDString) else {
            completionHandler()
            return
        }
        
        switch response.actionIdentifier {
        case "UPDATE_NOW":
            // Action to open the app; deep linking can be handled here if needed.
            break
            
        case "SNOOZE":
            snoozeNotification(response.notification.request)
            
        case "MUTE":
            muteTask(taskID: taskID)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func snoozeNotification(_ originalRequest: UNNotificationRequest) {
        let center = UNUserNotificationCenter.current()
        let newContent = originalRequest.content
        // Snooze for 24 hours (86400 seconds)
        let newTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 86400, repeats: false)
        let newRequest = UNNotificationRequest(
            identifier: "Snooze-\(UUID().uuidString)",
            content: newContent,
            trigger: newTrigger
        )
        center.add(newRequest)
    }
    
    private func muteTask(taskID: UUID) {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ChecklistTask>(predicate: #Predicate { $0.id == taskID })
        if let tasks = try? context.fetch(descriptor), let task = tasks.first {
            task.isMuted = true
            try? context.save()
            // Remove any pending time-based reminders for this task to clean up the queue
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["TMinus-\(taskID.uuidString)", "HeroTaskReminder"])
        }
    }
    
    // Ensures notifications show up even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
