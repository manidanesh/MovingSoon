import SwiftUI
import SwiftData
import CoreLocation

/// Notification choices remain accessible without enabling location access.
struct ReminderControlsView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var location = LocationManager.shared
    @State private var reminders = SmartReminderService.shared
    @State private var remainingNearbyAlerts = NotificationBudget.remainingToday()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            Form {
                Section("Checklist notifications") {
                    Label(reminders.isAuthorized ? "Notifications allowed" : "Notifications are off", systemImage: "bell")
                    Text("Date reminders work without location access. iOS controls delivery and may delay alerts.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if !reminders.isAuthorized {
                        Button("Enable checklist notifications") { reminders.requestPermissions() }
                    }
                    Button("Notification settings") { openSettings() }
                    Button("Refresh reminders") { reminders.reschedule(for: move) }
                    scheduleCoverage
                    if let error = reminders.schedulingError {
                        Text(error).font(.footnote).foregroundStyle(Theme.accentWarning)
                    }
                }
                Section("Nearby reminders") {
                    Text(locationStatus(at: timeline.date))
                    if ReminderPolicy.shouldOfferConsentRenewal(for: move, now: timeline.date) {
                        Text("Critical tasks remain on your checklist. Nearby reminders are paused because your 30-day window ended. You can choose whether to enable another 30 days.")
                            .font(.subheadline).foregroundStyle(Theme.accentWarning)
                    }
                    Text("An explicit choice enables a 30-day window. Background reminders require Always location permission, with Precise Location enabled for provider zones. Matching depends on places reported by Apple Maps and iOS.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Nearby alerts have their own limit of \(NotificationBudget.maximumNearbyPerDay) per day, separate from morning and date reminders. \(remainingNearbyAlerts) remaining today.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Nearby alerts run from 9 a.m. to 7 p.m., pause once the checklist is 80% complete, and notify at most once per place category per day. Destination zones cover selected branches within 8 km; visit reminders elsewhere depend on iOS detecting a stop.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if ReminderPolicy.consentIsActive(for: move, now: timeline.date) {
                        if let start = move.locationConsentGrantedAt,
                           let end = Calendar.current.date(byAdding: .day, value: 30, to: start) {
                            Text("Enabled until \(end.formatted(date: .abbreviated, time: .shortened))")
                                .font(.footnote)
                        }
                        Button("Stop nearby reminders", role: .destructive) { location.stopLocationReminders() }
                        if location.authorizationStatus != .authorizedAlways {
                            Button("Allow background reminders") { location.requestPermissions(); openSettings() }
                        }
                    } else if location.authorizationStatus != .restricted {
                        Button(move.locationConsentGrantedAt == nil ? "Enable for 30 days" : "Enable another 30 days") {
                            location.requestPermissions()
                            if location.authorizationStatus == .denied { openSettings() }
                        }
                    }
                    Button("Location settings") { openSettings() }
                    if let error = location.lastError {
                        Text(error).font(.footnote).foregroundStyle(Theme.accentWarning)
                    }
                    Text("Stopping nearby reminders leaves checklist notifications available. The app never renews location consent automatically.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Reminders")
        .task { refreshState() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshState() } }
    }

    private var scheduleCoverage: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Date alerts use a rolling \(ReminderScheduleBuilder.horizonDays)-day window. Critical check-ins cover the next \(ReminderScheduleBuilder.criticalReminderDays) days. Open the app regularly to refresh them.")
            if let coverage = reminders.coverage {
                Text("Next refresh recommended by \(coverage.refreshRecommendedAt.formatted(date: .abbreviated, time: .shortened)).")
                if coverage.deferredRequestCount + reminders.capacityDeferredCount > 0 {
                    Text("\(coverage.deferredRequestCount + reminders.capacityDeferredCount) later or excess alerts are not queued. Their tasks and dates remain on your checklist.")
                }
                if coverage.capacityLimited || reminders.capacityDeferredCount > 0 {
                    Text("The notification queue is full. One slot is reserved for a location-renewal reminder when eligible; earlier checklist alerts take the remaining slots. Refresh after alerts arrive.")
                        .foregroundStyle(Theme.accentWarning)
                }
            }
        }.font(.footnote).foregroundStyle(.secondary)
    }

    private func locationStatus(at now: Date) -> String {
        if move.locationConsentStoppedAt != nil { return "Nearby reminders stopped" }
        if !ReminderPolicy.consentIsActive(for: move, now: now) { return move.locationConsentGrantedAt == nil ? "Nearby reminders not enabled" : "Your 30-day window ended" }
        if location.authorizationStatus == .denied || location.authorizationStatus == .restricted { return "Location permission is off" }
        if location.accuracyAuthorization == .reducedAccuracy { return "Enable Precise Location for nearby provider alerts" }
        if !reminders.isAuthorized { return "Nearby reminders need notification permission" }
        if !SuppressionEngine.completionGatePasses(fraction: move.completionFraction) { return "Nearby reminders paused: checklist is at least 80% complete" }
        if remainingNearbyAlerts == 0 { return "Today’s nearby reminder limit has been reached" }
        if !SuppressionEngine.timeOfDayGatePasses(now: now) { return "Nearby reminders pause outside 9 a.m.–7 p.m." }
        return location.backgroundRemindersEnabled ? "Background nearby reminders enabled" : "Nearby reminders need location permission for background use"
    }

    private func refreshState() {
        remainingNearbyAlerts = NotificationBudget.remainingToday()
        location.attach(move, context: modelContext)
        reminders.refreshPermissions()
        reminders.reschedule(for: move)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Reversible task choices, suitable for an existing task-detail sheet or Form.
struct TaskReminderControls: View {
    let task: ChecklistTask
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Task reminders").font(.headline)
            if task.isMuted {
                Text("Reminders for this task are muted.").font(.subheadline).foregroundStyle(.secondary)
                Button("Unmute reminders") { apply("UNMUTE") }
            } else {
                Button("Mute reminders") { apply("MUTE") }
                if task.snoozedUntil == nil { Button("Snooze for 24 hours") { apply("SNOOZE") } }
            }
            if let until = task.snoozedUntil {
                Text("Snoozed until \(until.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Clear snooze") { apply("CLEAR_SNOOZE") }
            }
            Text("Date alerts are queued within the next 30 days, subject to available notification slots. Later dates stay on your checklist; reopen the app to refresh reminders.")
                .font(.footnote).foregroundStyle(.secondary)
            if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(Theme.accentWarning) }
        }
        .disabled(task.status != .toDo || move.phase != .active)
    }

    private func apply(_ action: String) {
        do {
            guard move.phase == .active,
                  try NotificationTaskAction.applyAndSave(action, to: task, save: { try modelContext.save() }) else { return }
            errorMessage = nil
            LocationManager.shared.attach(move, context: modelContext)
            SmartReminderService.shared.reschedule(for: move)
        } catch { errorMessage = "Your reminder choice couldn’t be saved. Try again." }
    }
}
