import Foundation
import UserNotifications

struct ReminderScheduleCoverage {
    let horizonEnd: Date
    let criticalReminderEnd: Date
    let refreshRecommendedAt: Date
    let deferredRequestCount: Int
    let capacityLimited: Bool
}

struct ReminderSchedulePlan {
    let requests: [UNNotificationRequest]
    let coverage: ReminderScheduleCoverage
}

/// Pure schedule construction shared by foreground edits and notification actions.
/// Requests are one-shot so an unattended critical reminder cannot repeat forever.
enum ReminderScheduleBuilder {
    static let horizonDays = 30
    static let criticalReminderDays = 7
    static let maximumRequests = 60

    static func requests(for move: Move, now: Date = Date(), calendar: Calendar = .current) -> [UNNotificationRequest] {
        plan(for: move, now: now, calendar: calendar).requests
    }

    static func plan(for move: Move, now: Date = Date(), calendar: Calendar = .current) -> ReminderSchedulePlan {
        let horizonEnd = calendar.date(byAdding: .day, value: horizonDays, to: now) ?? now
        let criticalEnd = calendar.date(byAdding: .day, value: criticalReminderDays,
            to: calendar.startOfDay(for: now)) ?? now
        let empty = ReminderSchedulePlan(requests: [], coverage: ReminderScheduleCoverage(horizonEnd: horizonEnd,
            criticalReminderEnd: criticalEnd, refreshRecommendedAt: criticalEnd, deferredRequestCount: 0, capacityLimited: false))
        guard move.phase == .active else { return empty }
        let moveDate = move.moveDate(calendar: calendar)
        let tasks = move.tasks.filter { $0.status == .toDo && !$0.isMuted && $0.needsLocationReview != true }
            .sorted { $0.isDueBefore($1, moveDate: moveDate, calendar: calendar) }
        guard !tasks.isEmpty else { return empty }
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
        for day in 0..<criticalReminderDays {
            guard let start = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: now)) else { continue }
            for hour in [10, 18] {
                guard let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start), fire > now else { continue }
                let remaining = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: moveDate)).day ?? 0
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
                    to: task.baseDueDate(moveDate: moveDate, calendar: calendar)) else { continue }
                queue(task, on: day, detail: offset == 0 ? "address review due today" : "address review due in 3 days")
            }
            for (kind, date) in [("shipment", task.shipmentDate(calendar: calendar)), ("renewal", task.renewalDate(calendar: calendar))] {
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
            let entries = bucket.values.sorted { $0.task.isDueBefore($1.task, moveDate: moveDate, calendar: calendar) }
            let names = entries.prefix(3).map { "\($0.task.title) — \($0.details.joined(separator: "; "))" }.joined(separator: "\n")
            let extra = entries.count > 3 ? "\nAnd \(entries.count - 3) more address updates." : ""
            add(id: "Digest-\(Int(date.timeIntervalSince1970))", title: "Address updates to review", body: names + extra,
                date: date, items: entries.map(\.task))
        }
        let active = tasks.filter { ReminderPolicy.isEligible($0, at: now) }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                          to: calendar.startOfDay(for: moveDate)).day ?? 0
        if days > 0, let fire = calendar.date(byAdding: .day, value: max(1, min(4, days / 3)), to: now) {
            add(id: "ReengagementReminder", title: "Your checklist is here when you're ready",
                body: "You still have address updates to review before moving day.", date: fire, items: active)
        }
        if let day = calendar.date(byAdding: .day, value: 14, to: moveDate),
           let fire = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: day) {
            add(id: "PostMoveCheckIn", title: "How did the move go?",
                body: "Take a moment to check any address updates that are still open.", date: fire,
                items: tasks.filter { ReminderPolicy.isEligible($0, at: fire) })
        }
        // A bounded rolling window is explicit in settings. Far-future dates stay
        // on the checklist until a later app visit refreshes this one-shot queue.
        // Day digests batch all tasks; earlier alerts take precedence at capacity.
        let sorted = output.sorted { $0.0 == $1.0 ? $0.1.identifier < $1.1.identifier : $0.0 < $1.0 }
        let inWindow = sorted.filter { $0.0 <= horizonEnd }
        let renewal = LocationConsentRenewal.request(for: move, now: now, calendar: calendar)
        // Reserve one slot for the consent deadline. Quiet hours may move this
        // one bounded event just past the usual rolling 30-day date horizon.
        let ordinaryLimit = maximumRequests - (renewal == nil ? 0 : 1)
        let selected = Array(inWindow.prefix(ordinaryLimit))
        let firstOmitted = inWindow.dropFirst(ordinaryLimit).first?.0
        let refresh = min(criticalEnd, firstOmitted ?? criticalEnd)
        var requests = selected.map(\.1)
        if let renewal { requests.insert(renewal, at: 0) }
        return ReminderSchedulePlan(requests: requests, coverage: ReminderScheduleCoverage(
            horizonEnd: horizonEnd, criticalReminderEnd: criticalEnd, refreshRecommendedAt: refresh,
            deferredRequestCount: sorted.count - selected.count, capacityLimited: inWindow.count > ordinaryLimit))
    }

    static func owns(_ identifier: String) -> Bool {
        ["Hero", "Digest-", "TMinus-", "Snooze-", "LocationReminder-"].contains { identifier.hasPrefix($0) }
            || ["ReengagementReminder", "PostMoveCheckIn"].contains(identifier)
            || LocationConsentRenewal.owns(identifier)
    }
}
