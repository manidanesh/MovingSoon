import Foundation
import UserNotifications

/// Pure schedule construction shared by foreground edits and notification actions.
/// Requests are one-shot so an unattended critical reminder cannot repeat forever.
enum ReminderScheduleBuilder {
    static func requests(for move: Move, now: Date = Date(), calendar: Calendar = .current) -> [UNNotificationRequest] {
        guard move.phase == .active else { return [] }
        let tasks = move.tasks.filter { $0.status == .toDo && !$0.isMuted && $0.needsLocationReview != true }
            .sorted { $0.isDueBefore($1, moveDate: move.anchorDate, calendar: calendar) }
        guard !tasks.isEmpty else { return [] }
        var output: [(Date, UNNotificationRequest)] = []
        func add(id: String, title: String, body: String, date: Date, items: [ChecklistTask]) {
            guard date > now, !items.isEmpty else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = ["moveID": move.id.uuidString, "taskIDs": items.map { $0.id.uuidString }]
            if items.count == 1, let task = items.first {
                content.categoryIdentifier = "TaskReminder"
                content.userInfo["taskID"] = task.id.uuidString
                if let url = task.deepLinkURL { content.userInfo["url"] = url.absoluteString }
            } else {
                content.categoryIdentifier = "DigestReminder"
                content.userInfo["action"] = "openDashboard"
            }
            // Calendar triggers have second precision. Round forward so a snooze
            // never expires early when the saved deadline has fractional seconds.
            let triggerDate = Date(timeIntervalSince1970: ceil(date.timeIntervalSince1970))
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
            output.append((date, UNNotificationRequest(identifier: id, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))))
        }
        for day in 0..<7 {
            guard let start = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: now)) else { continue }
            for hour in [10, 18] {
                guard let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start), fire > now else { continue }
                let remaining = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: move.anchorDate)).day ?? 0
                guard hour == 10 || (0...3).contains(remaining),
                      let hero = tasks.first(where: { $0.priority == .critical && ReminderPolicy.isEligible($0, at: fire) }) else { continue }
                add(id: "Hero-\(Int(fire.timeIntervalSince1970))", title: "An important address update",
                    body: "When you have a moment, check \(hero.title).", date: fire, items: [hero])
            }
        }
        struct Entry {
            let task: ChecklistTask
            var details: [String]
            var isAccountEvent: Bool
        }
        var buckets: [Date: [UUID: Entry]] = [:]
        func queue(_ task: ChecklistTask, on day: Date, detail: String, isAccountEvent: Bool = false) {
            guard let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                  fire > now, ReminderPolicy.isEligible(task, at: fire) else { return }
            var bucket = buckets[fire] ?? [:]
            if var entry = bucket[task.id] {
                if isAccountEvent {
                    if !entry.isAccountEvent { entry.details = [] }
                    if !entry.details.contains(detail) { entry.details.append(detail) }
                    entry.isAccountEvent = true
                    bucket[task.id] = entry
                }
            } else { bucket[task.id] = Entry(task: task, details: [detail], isAccountEvent: isAccountEvent) }
            buckets[fire] = bucket
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        for task in tasks {
            for offset in [-3, 0] {
                guard let day = calendar.date(byAdding: .day, value: offset,
                    to: task.baseDueDate(moveDate: move.anchorDate, calendar: calendar)) else { continue }
                queue(task, on: day, detail: offset == 0 ? "address review due today" : "address review due in 3 days")
            }
            for (kind, date) in [("shipment", task.nextShipmentDate), ("renewal", task.nextRenewalDate)] {
                guard let date else { continue }
                for offset in Set([-task.reminderLeadDays, 0]).sorted() {
                    guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)) else { continue }
                    let detail = offset == 0 ? "\(kind) date today" : "before \(kind) on \(formatter.string(from: date))"
                    queue(task, on: day, detail: detail, isAccountEvent: true)
                }
            }
            if let until = task.snoozedUntil, until > now {
                var fire = until
                let hour = calendar.component(.hour, from: fire)
                if hour < 9 { fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: fire) ?? fire }
                if hour >= 19, let tomorrow = calendar.date(byAdding: .day, value: 1, to: fire) {
                    fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? fire
                }
                add(id: "Snooze-\(task.id.uuidString)", title: "Ready to revisit this?",
                    body: "Your reminder for \(task.title) is back when you're ready.", date: fire, items: [task])
            }
        }
        for (date, bucket) in buckets {
            let entries = bucket.values.sorted { $0.task.isDueBefore($1.task, moveDate: move.anchorDate, calendar: calendar) }
            let names = entries.prefix(3).map { "\($0.task.title) — \($0.details.joined(separator: "; "))" }.joined(separator: "\n")
            let extra = entries.count > 3 ? "\nAnd \(entries.count - 3) more address updates." : ""
            add(id: "Digest-\(Int(date.timeIntervalSince1970))", title: "Address updates to review", body: names + extra,
                date: date, items: entries.map(\.task))
        }
        let active = tasks.filter { ReminderPolicy.isEligible($0, at: now) }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                          to: calendar.startOfDay(for: move.anchorDate)).day ?? 0
        if days > 0, let fire = calendar.date(byAdding: .day, value: max(1, min(4, days / 3)), to: now) {
            add(id: "ReengagementReminder", title: "Your checklist is here when you're ready",
                body: "You still have address updates to review before moving day.", date: fire, items: active)
        }
        if let day = calendar.date(byAdding: .day, value: 14, to: move.anchorDate),
           let fire = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: day) {
            add(id: "PostMoveCheckIn", title: "How did the move go?",
                body: "Take a moment to check any address updates that are still open.", date: fire,
                items: tasks.filter { ReminderPolicy.isEligible($0, at: fire) })
        }
        // Leave capacity for immediate notifications; deterministic chronological order.
        return output.sorted { $0.0 == $1.0 ? $0.1.identifier < $1.1.identifier : $0.0 < $1.0 }.prefix(60).map(\.1)
    }

    static func owns(_ identifier: String) -> Bool {
        ["Hero", "Digest-", "TMinus-", "Snooze-", "LocationReminder-"].contains { identifier.hasPrefix($0) }
            || ["ReengagementReminder", "PostMoveCheckIn"].contains(identifier)
    }
}
