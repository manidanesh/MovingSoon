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

        let taskCategory = UNNotificationCategory(
            identifier: "TaskReminder",
            actions: [updateAction, snoozeAction, muteAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Digest category — tapping opens the app dashboard
        let reviewAction = UNNotificationAction(identifier: "REVIEW_NOW", title: "Review Tasks", options: [.foreground])
        let digestCategory = UNNotificationCategory(
            identifier: "DigestReminder",
            actions: [reviewAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([taskCategory, digestCategory])
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
        var userInfo: [AnyHashable: Any] = ["taskID": task.id.uuidString]
        if let url = task.deepLinkURL {
            userInfo["url"] = url.absoluteString
        }
        content.userInfo = userInfo
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
        // Only remove the previous hero task reminder — not ALL pending notifications
        center.removePendingNotificationRequests(withIdentifiers: ["HeroTaskReminder"])

        guard let task = heroTask, task.status == .toDo else { return }
        
        // Anti-Nag Protocol: Only nag for Critical operations
        guard task.priority == .critical, !task.isMuted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Critical Action Required"
        content.body = "You have an urgent pending task: \(task.title). Please update this immediately."
        var userInfo: [AnyHashable: Any] = ["taskID": task.id.uuidString]
        if let url = task.deepLinkURL {
            userInfo["url"] = url.absoluteString
        }
        content.userInfo = userInfo
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

    // MARK: - T-Minus Digest Reminders
    //
    // Instead of one notification per task (spam), we send ONE digest notification
    // per day summarising all tasks due around that time.
    // Tapping opens the app dashboard where the user can see all open items.

    func scheduleTMinusReminders(tasks: [ChecklistTask], moveDate: Date) {
        let center = UNUserNotificationCenter.current()

        // Remove all previously scheduled digest notifications
        center.getPendingNotificationRequests { requests in
            let digestIds = requests
                .filter { $0.identifier.hasPrefix("Digest-") || $0.identifier.hasPrefix("TMinus-") }
                .map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: digestIds)
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let moveStartOfDay = calendar.startOfDay(for: moveDate)

        // Group pending tasks by the day their 3-day warning should fire
        var tasksByFireDay: [Date: [ChecklistTask]] = [:]

        for task in tasks where task.status != .completed && !task.isMuted {
            guard let dueDate = calendar.date(byAdding: .day, value: task.tMinusDays, to: moveStartOfDay) else { continue }
            guard let fireDay = calendar.date(byAdding: .day, value: -3, to: dueDate) else { continue }
            let fireDayStart = calendar.startOfDay(for: fireDay)
            // Only schedule future notifications
            guard fireDayStart >= today else { continue }
            tasksByFireDay[fireDayStart, default: []].append(task)
        }

        // Schedule ONE digest notification per unique fire day
        for (fireDay, dayTasks) in tasksByFireDay {
            let content = UNMutableNotificationContent()
            let count = dayTasks.count

            if count == 1 {
                let name = dayTasks[0].institutionName ?? dayTasks[0].title
                content.title = "Address update due soon"
                content.body = "\(name) needs your new address in 3 days."
            } else {
                // List up to 3 task names, then summarise the rest
                let names = dayTasks.prefix(3).map { $0.institutionName ?? $0.title }
                let listed = names.joined(separator: ", ")
                let extra = count > 3 ? " and \(count - 3) more" : ""
                content.title = "\(count) address updates due soon"
                content.body = "\(listed)\(extra) — all due in 3 days."
            }

            content.sound = .default
            content.categoryIdentifier = "DigestReminder"
            content.userInfo = ["action": "openDashboard"]

            var triggerDate = calendar.dateComponents([.year, .month, .day], from: fireDay)
            triggerDate.hour = 9
            triggerDate.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let identifier = "Digest-\(Int(fireDay.timeIntervalSince1970))"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }
}
