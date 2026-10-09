import Foundation
import UserNotifications
import OSLog

@MainActor protocol ReminderNotificationCenter {
    func pending() async -> [UNNotificationRequest]
    func delivered() async -> [UNNotificationRequest]
    func authorized() async -> Bool
    func requestPermission() async -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePending(_ identifiers: [String])
    func removeDelivered(_ identifiers: [String])
}

@MainActor struct SystemReminderNotificationCenter: ReminderNotificationCenter {
    private var center: UNUserNotificationCenter { .current() }
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func delivered() async -> [UNNotificationRequest] { await center.deliveredNotifications().map(\.request) }
    func authorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }
    func requestPermission() async -> Bool { (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func removePending(_ identifiers: [String]) { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
    func removeDelivered(_ identifiers: [String]) { center.removeDeliveredNotifications(withIdentifiers: identifiers) }
}

@MainActor @Observable
final class SmartReminderService {
    static let shared = SmartReminderService()
    private(set) var isAuthorized = false
    private let center: any ReminderNotificationCenter
    private let hasLocationBudget: () async -> Bool
    private let recordLocationDelivery: () -> Void
    private var desired: [UNNotificationRequest] = []
    private var revision = 0
    private var worker: Task<Void, Never>?
    private var move: Move?
    private var sendingLocation = false
    private let logger = Logger(subsystem: "app.movingsoon", category: "Reminders")

    init(center: (any ReminderNotificationCenter)? = nil, registerCategories: Bool = true,
         hasLocationBudget: @escaping () async -> Bool = { await NotificationBudget.hasRoomToday() },
         recordLocationDelivery: @escaping () -> Void = { NotificationBudget.recordFired() }) {
        self.center = center ?? SystemReminderNotificationCenter()
        self.hasLocationBudget = hasLocationBudget
        self.recordLocationDelivery = recordLocationDelivery
        if registerCategories {
            let task = UNNotificationCategory(identifier: "TaskReminder", actions: [
                UNNotificationAction(identifier: "UPDATE_NOW", title: "Update Now", options: [.foreground]),
                UNNotificationAction(identifier: "SNOOZE", title: "Snooze for 24 Hours", options: []),
                UNNotificationAction(identifier: "MUTE", title: "Mute Task", options: [.destructive])
            ], intentIdentifiers: [], options: .customDismissAction)
            let digest = UNNotificationCategory(identifier: "DigestReminder", actions: [
                UNNotificationAction(identifier: "REVIEW_NOW", title: "Review Tasks", options: [.foreground])
            ], intentIdentifiers: [])
            UNUserNotificationCenter.current().setNotificationCategories([task, digest])
            refreshPermissions()
        }
    }

    func refreshPermissions() { Task { isAuthorized = await center.authorized() } }
    func requestPermissions() { Task { isAuthorized = await center.requestPermission() } }

    func reschedule(for move: Move?, now: Date = Date()) {
        self.move = move
        desired = move.map { ReminderScheduleBuilder.requests(for: $0, now: now) } ?? []
        revision += 1
        guard worker == nil else { return }
        worker = Task { await reconcile() }
    }

    func waitForSchedule() async { await worker?.value }

    /// One writer drains the latest schedule. A new edit never races an earlier
    /// asynchronous remove/add cycle, including edits made from notification actions.
    private func reconcile() async {
        while true {
            let version = revision
            let pending = await center.pending()
            guard version == revision else { continue }
            center.removePending(pending.filter { ReminderScheduleBuilder.owns($0.identifier) }.map(\.identifier))
            let delivered = await center.delivered()
            guard version == revision else { continue }
            let eligible = Set(move?.tasks.filter { ReminderPolicy.isEligible($0) }.map { $0.id.uuidString } ?? [])
            center.removeDelivered(delivered.filter { request in
                guard ReminderScheduleBuilder.owns(request.identifier) else { return false }
                let ids = (request.content.userInfo["taskIDs"] as? [String])
                    ?? (request.content.userInfo["taskID"] as? String).map { [$0] } ?? []
                return ids.isEmpty || !Set(ids).isSubset(of: eligible)
            }.map(\.identifier))
            let requests = desired
            for request in requests {
                guard version == revision else { break }
                do { try await center.add(request) }
                catch { logger.error("Unable to schedule a reminder.") }
            }
            if version == revision { break }
        }
        worker = nil
    }

    func fireLocationNotification(task: ChecklistTask, poiCategory: POICategory,
                                  stillRelevant: () -> Bool) async -> Bool {
        guard !sendingLocation else { return false }
        sendingLocation = true
        defer { sendingLocation = false }
        guard await center.authorized(), await hasLocationBudget(),
              stillRelevant(), ReminderPolicy.isEligible(task) else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Address update nearby"
        content.body = "A nearby place may help with \(task.title). Check your account when convenient."
        content.sound = .default
        content.categoryIdentifier = "TaskReminder"
        content.userInfo = ["taskID": task.id.uuidString, "taskIDs": [task.id.uuidString]]
        if let move = task.move { content.userInfo["moveID"] = move.id.uuidString }
        if let url = task.deepLinkURL { content.userInfo["url"] = url.absoluteString }
        let request = UNNotificationRequest(identifier: "LocationReminder-\(task.id.uuidString)", content: content, trigger: nil)
        do {
            try await center.add(request)
            guard stillRelevant(), ReminderPolicy.isEligible(task) else {
                center.removePending([request.identifier])
                center.removeDelivered([request.identifier])
                return false
            }
            recordLocationDelivery()
            return true
        } catch {
            logger.error("Unable to submit nearby reminder.")
            return false
        }
    }
}
