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
        NotificationBudget.recordFired()
    }

    // MARK: - Hero task daily reminder

    /// Schedules a nagging push notification ONLY for the current Hero Task, and ONLY
    /// if it is a Critical Priority. Cadence escalates as the move gets closer — a flat
    /// once-a-day nudge either nags too early or falls silent exactly when it matters
    /// most, so within the final 3 days a second, evening nudge is added.
    func scheduleHeroTaskReminder(heroTask: ChecklistTask?, daysUntilMove: Int) {
        let center = UNUserNotificationCenter.current()
        // Only remove the previous hero task reminders — not ALL pending notifications
        center.removePendingNotificationRequests(withIdentifiers: ["HeroTaskReminder", "HeroTaskReminderEvening"])

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

        scheduleDailyHero(identifier: "HeroTaskReminder", hour: 10, content: content, center: center)

        // Final stretch — add an evening nudge on top of the morning one.
        if daysUntilMove <= 3 {
            scheduleDailyHero(identifier: "HeroTaskReminderEvening", hour: 18, content: content, center: center)
        }
    }

    private func scheduleDailyHero(identifier: String, hour: Int, content: UNMutableNotificationContent, center: UNUserNotificationCenter) {
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
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

        // Two tiers per task: a 3-day warning, and a same-day nudge on the due date
        // itself — previously a task that slipped past its one T-3 warning generated
        // zero further pushes, however overdue it became.
        struct Tier { let offsetFromDue: Int; let label: String }
        let tiers = [Tier(offsetFromDue: -3, label: "in 3 days"), Tier(offsetFromDue: 0, label: "today")]

        // Group pending tasks by (fire day, tier label) so a same-day due task and a
        // 3-days-out task never merge into one confusingly-worded digest.
        var tasksByFireDay: [Date: (label: String, tasks: [ChecklistTask])] = [:]

        for task in tasks where task.status != .completed && !task.isMuted {
            guard let dueDate = calendar.date(byAdding: .day, value: task.tMinusDays, to: moveStartOfDay) else { continue }
            for tier in tiers {
                guard let fireDay = calendar.date(byAdding: .day, value: tier.offsetFromDue, to: dueDate) else { continue }
                let fireDayStart = calendar.startOfDay(for: fireDay)
                guard fireDayStart >= today else { continue }
                // Key by day + tier so the two tiers never collide into one bucket.
                let key = calendar.date(byAdding: .hour, value: tier.offsetFromDue == 0 ? 1 : 0, to: fireDayStart) ?? fireDayStart
                var bucket = tasksByFireDay[key] ?? (label: tier.label, tasks: [])
                bucket.tasks.append(task)
                tasksByFireDay[key] = bucket
            }
        }

        // Schedule ONE digest notification per unique (fire day, tier) bucket
        for (fireDay, bucket) in tasksByFireDay {
            let content = UNMutableNotificationContent()
            let count = bucket.tasks.count
            let dayTasks = bucket.tasks
            let when = bucket.label

            if count == 1 {
                let name = dayTasks[0].institutionName ?? dayTasks[0].title
                content.title = when == "today" ? "Address update due today" : "Address update due soon"
                content.body = "\(name) needs your new address \(when)."
            } else {
                // List up to 3 task names, then summarise the rest
                let names = dayTasks.prefix(3).map { $0.institutionName ?? $0.title }
                let listed = names.joined(separator: ", ")
                let extra = count > 3 ? " and \(count - 3) more" : ""
                content.title = when == "today" ? "\(count) address updates due today" : "\(count) address updates due soon"
                content.body = "\(listed)\(extra) — all due \(when)."
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

    // MARK: - Re-engagement (win-back) reminder
    //
    // Every other channel is keyed to a task's due date. This one is keyed to the user
    // going quiet: rescheduled forward every time the dashboard loads, so it only ever
    // fires during a real gap in engagement — if the user reopens the app before it
    // fires, this call replaces it with a new one further out.

    func scheduleReengagementReminder(openTaskCount: Int, daysUntilMove: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["ReengagementReminder"])

        // Nothing to come back for, or the move already happened — digest/post-move
        // channels cover those cases instead.
        guard openTaskCount > 0, daysUntilMove > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Still there?"
        content.body = openTaskCount == 1
            ? "You have 1 address update still open, and moving day is in \(daysUntilMove) days."
            : "You have \(openTaskCount) address updates still open, and moving day is in \(daysUntilMove) days."
        content.sound = .default
        content.categoryIdentifier = "DigestReminder"
        content.userInfo = ["action": "openDashboard"]

        // Closer to the move, a quiet spell matters faster — shrink the window from
        // 4 days down to 1 as daysUntilMove runs out.
        let delayDays = max(1, min(4, daysUntilMove / 3))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delayDays * 86400), repeats: false)
        let request = UNNotificationRequest(identifier: "ReengagementReminder", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Post-move check-in
    //
    // The one channel that must NOT depend on the user reopening the app to stay
    // primed — its whole purpose is winning back someone who has stopped engaging
    // right around the moment the move itself starts to feel "done." Scheduled once
    // whenever the dashboard loads with a future move date; since it's a single
    // calendar-triggered request already queued with the OS, it still fires two weeks
    // after move day even if the app is never opened again before then.

    func schedulePostMoveCheckIn(moveDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["PostMoveCheckIn"])

        let calendar = Calendar.current
        guard let fireDate = calendar.date(byAdding: .day, value: 14, to: moveDate),
              fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "How did the move go?"
        content.body = "Check off anything you've finished — we'll remind you about what's still open."
        content.sound = .default
        content.categoryIdentifier = "DigestReminder"
        content.userInfo = ["action": "openDashboard"]

        var triggerDate = calendar.dateComponents([.year, .month, .day], from: fireDate)
        triggerDate.hour = 11
        triggerDate.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: "PostMoveCheckIn", content: content, trigger: trigger)
        center.add(request)
    }
}
