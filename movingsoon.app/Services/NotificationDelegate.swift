import Foundation
import UserNotifications
import SwiftData
import UIKit

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
        
        let urlString = userInfo["url"] as? String
        
        switch response.actionIdentifier {
        case "UPDATE_NOW", UNNotificationDefaultActionIdentifier:
            // Check if this is a digest notification — just open the app (no deep link)
            let action = userInfo["action"] as? String
            if action == "openDashboard" {
                // App opens to dashboard automatically — nothing extra needed
                break
            }
            if let urlString = urlString, let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }

        case "REVIEW_NOW":
            // Digest notification tapped — app opens to dashboard automatically
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
        // SwiftData mutations must happen on the main thread
        DispatchQueue.main.async {
            let context = ModelContext(self.modelContainer)
            let descriptor = FetchDescriptor<ChecklistTask>(predicate: #Predicate { $0.id == taskID })
            if let tasks = try? context.fetch(descriptor), let task = tasks.first {
                task.isMuted = true
                try? context.save()
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: ["TMinus-\(taskID.uuidString)", "HeroTaskReminder"])
            }
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
