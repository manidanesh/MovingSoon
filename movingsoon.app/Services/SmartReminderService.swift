// SmartReminderService.swift — Anti-Nag Push Notification Protocol
import Foundation
import UserNotifications

@Observable
final class SmartReminderService {
    var isAuthorized: Bool = false

    init() {
        checkPermissions()
    }

    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }

    private func checkPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }

    /// Schedules a daily nagging push notification ONLY for the current Hero Task,
    /// and ONLY if it is a Critical Priority.
    func scheduleHeroTaskReminder(heroTask: ChecklistTask?) {
        let center = UNUserNotificationCenter.current()
        // Clear previous reminders to ensure we only nag about the current Hero Task
        center.removeAllPendingNotificationRequests()

        guard let task = heroTask, task.status == .toDo else { return }
        
        // Anti-Nag Protocol: Only nag for Critical operations
        guard task.priority == .critical else { return }

        let content = UNMutableNotificationContent()
        content.title = "Critical Action Required"
        content.body = "You have an urgent pending task: \(task.title). Please update this immediately."
        content.sound = .default
        
        // Schedule for 10:00 AM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "HeroTaskReminder", content: content, trigger: trigger)
        center.add(request)
    }
}
