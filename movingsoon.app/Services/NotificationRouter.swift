// NotificationRouter.swift — hands a tapped notification's task off to the dashboard
import Foundation

/// `NotificationDelegate` runs outside SwiftUI (no environment/view access), so it can't
/// present `TaskActionSheet` itself. It drops the tapped task's ID here; `ZenDashboardView`
/// observes `pendingTaskID` and presents the same choice sheet used everywhere else in the
/// app, rather than the notification jumping straight to an external site.
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()
    var pendingTaskID: UUID?
    private init() {}
}
