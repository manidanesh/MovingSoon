// SmartReminderService.swift — Anti-Nag Push Notification Protocol
import Foundation
import UserNotifications

@Observable
final class SmartReminderService {
    var isAuthorized: Bool = false

    init() {
        checkPermissions()
        registerCategories()
    }

    private func registerCategories() {
        let updateAction = UNNotificationAction(identifier: "UPDATE_NOW", title: "Update Now", options: [.foreground])
        let snoozeAction = UNNotificationAction(identifier: "SNOOZE", title: "Snooze for 24 Hours", options: [])
        let muteAction = UNNotificationAction(identifier: "MUTE", title: "Mute Task", options: [.destructive])
        
        let category = UNNotificationCategory(
            identifier: "TaskReminder",
            actions: [updateAction, snoozeAction, muteAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
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

    // MARK: - Location-triggered notification

    /// Fires an immediate local notification when the user enters a geofenced POI area.
    /// Called by LocationManager after SuppressionEngine clears all six gates.
    func fireLocationNotification(task: ChecklistTask, poiCategory: POICategory) {
        let content = UNMutableNotificationContent()
        content.title = "Address update nearby"
        content.body = "You're near a \(poiCategory.displayName) — update your address while you're here."
        content.userInfo = ["taskID": task.id.uuidString]
        content.sound = .default
        content.categoryIdentifier = "TaskReminder"

        // Fire immediately (nil trigger)
        let request = UNNotificationRequest(
            identifier: "LocationReminder-\(task.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Hero task daily reminder

    /// Schedules a daily nagging push notification ONLY for the current Hero Task,
    /// and ONLY if it is a Critical Priority.
    func scheduleHeroTaskReminder(heroTask: ChecklistTask?) {
        let center = UNUserNotificationCenter.current()
        // Clear previous reminders to ensure we only nag about the current Hero Task
        center.removeAllPendingNotificationRequests()

        guard let task = heroTask, task.status == .toDo else { return }
        
        // Anti-Nag Protocol: Only nag for Critical operations
        guard task.priority == .critical, !task.isMuted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Critical Action Required"
        content.body = "You have an urgent pending task: \(task.title). Please update this immediately."
        content.userInfo = ["taskID": task.id.uuidString]
        content.sound = .default
        content.categoryIdentifier = "TaskReminder"
        
        // Schedule for 10:00 AM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "HeroTaskReminder", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - T-Minus Reminders

    /// Scans unfinished tasks and schedules local notifications for tasks that are
    /// exactly 3 days away from their due date based on the user's moveDate.
    func scheduleTMinusReminders(tasks: [ChecklistTask], moveDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let tMinusIds = requests.filter { $0.identifier.hasPrefix("TMinus-") }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: tMinusIds)
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let moveStartOfDay = calendar.startOfDay(for: moveDate)

        for task in tasks where task.status != .completed && !task.isMuted {
            guard let dueDate = calendar.date(byAdding: .day, value: task.tMinusDays, to: moveStartOfDay) else { continue }
            
            // Calculate days left until due date
            let components = calendar.dateComponents([.day], from: today, to: dueDate)
            guard let daysLeft = components.day, daysLeft == 3 else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Task Due Soon"
            
            let displayName = task.institutionName ?? task.title
            content.body = "You have 3 days left to update your address with \(displayName)."
            content.userInfo = ["taskID": task.id.uuidString]
            content.sound = .default
            content.categoryIdentifier = "TaskReminder"
            
            // Schedule for 9:00 AM on the day that is 3 days before due
            var triggerDate = calendar.dateComponents([.year, .month, .day], from: Date())
            triggerDate.hour = 9
            triggerDate.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
                identifier: "TMinus-\(task.id.uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}
