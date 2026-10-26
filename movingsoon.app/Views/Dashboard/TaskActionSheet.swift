import SwiftUI
import SwiftData

// MARK: - Task Action Sheet
struct TaskActionSheet: View {
    let task: ChecklistTask
    @Environment(\.modelContext) private var modelContext
    let onAlreadyDone: () -> Void
    let onUpdateNow: () -> Void
    let onLater: () -> Void
    /// Permanently removes the task from the move — not a status, an actual
    /// deletion (see the confirmation copy below). Catalog-generated tasks like
    /// "Mathnasium — Update Account" or "Goldfish Swim School" are matched from
    /// broad lifestyle flags (e.g. "has children") that can't know which specific
    /// activities a family actually uses, so a wrong match needs a real way to
    /// leave and never come back — not just a snooze.
    let onNotApplicable: () -> Void

    @State private var showingRemoveConfirm = false
    @State private var showingAccountEditor = false

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            // Handle + title
            VStack(alignment: .leading, spacing: 6) {
                Text(task.category.rawValue)
                    .themeText(11, weight: .semibold)
                    .foregroundColor(Theme.accentPrimary)
                    .textCase(.uppercase)
                    .tracking(1.5)
                Text("\(task.category.emoji) \(task.title)")
                    .themeSerif(20, weight: .bold)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.top, 8)

            if task.needsLocationReview == true {
                Text("This task came from your previous location choices. Confirm it still applies or remove it below.")
                    .font(.subheadline).foregroundStyle(Theme.accentWarning)
                Button("This still applies") {
                    ChecklistActions.perform(in: modelContext, move: task.move) {
                        if let move = task.move, let id = MoveChecklistService.catalogID(for: task) {
                            move.respond(to: id, with: .confirmed)
                        }
                        task.needsLocationReview = false
                    }
                }
            }

            if let move = task.move {
                AccountDatesSummaryView(task: task)
                Button(task.isUserAdded ? "Edit task" : "Edit account & reminder dates") { showingAccountEditor = true }
                    .font(.subheadline.weight(.semibold))
                TaskAssignmentButton(task: task)
                TaskReminderControls(task: task, move: move)
                if !task.isUserAdded {
                    DisclosureGroup("How to handle this") { TaskGuidanceView(task: task, move: move).padding(.top, 8) }
                        .font(.subheadline.weight(.semibold))
                }
            }
            if task.moveAction != .updateAddress {
                Text(task.moveAction.title).font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
            if let id = MoveChecklistService.catalogID(for: task), let guidance = ItemCatalog.byID[id]?.moveGuidance {
                VStack(alignment: .leading, spacing: 6) {
                    Text("For this move").font(.subheadline.weight(.semibold))
                    Text(guidance).font(.subheadline).foregroundStyle(Theme.textSecondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if let note = task.customerNote, !note.isEmpty {
                ScrollView { Text(note).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 100)
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: 10) {
                // Primary: take the action, if there's a link to take it with —
                // matches Hero Card's hierarchy (Update Now leads when possible).
                // Blue = "take the external action" everywhere in this app.
                if task.actionURL != nil {
                    Button(action: onUpdateNow) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right")
                                .themeText(14, weight: .bold)
                            Text(task.moveAction == .updateAddress ? "Update address" : "Open provider")
                                .themeText(16, weight: .bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.accentPrimary)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                // Confirm done. Green = "confirmed done" everywhere in this app —
                // the same color law as Hero Card and the geofence prompt.
                Button {
                    if task.status == .completed {
                        if ChecklistActions.reopen(task, in: modelContext) { onLater() }
                    } else { onAlreadyDone() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .themeText(14, weight: .bold)
                        Text(task.status == .completed ? "Reopen task & resume reminders" : "Mark as Done")
                            .themeText(16, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(task.actionURL != nil ? Theme.backgroundElevated : Theme.accentSuccess)
                    .foregroundColor(task.actionURL != nil ? Theme.accentSuccess : .black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                // Tertiary: later
                Button(action: onLater) {
                    Text("I'll do this later")
                        .themeText(14, weight: .medium)
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                // Destructive: not applicable to this user at all — distinct from
                // "later" (still on the list, just deferred). Tinted, not filled,
                // so it doesn't compete visually with Update Now / Mark as Done.
                Button {
                    showingRemoveConfirm = true
                } label: {
                    Text(task.hasAccountDetails ? "Remove this account" : "Not Applicable")
                        .themeText(13, weight: .medium)
                        .foregroundColor(Theme.priorityCritical.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.backgroundCard)
        .confirmationDialog(
            "Remove \"\(task.title)\"?",
            isPresented: $showingRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive, action: onNotApplicable)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(task.hasAccountDetails ? "This removes only this account and its reminders. Other accounts stay on your checklist."
                : task.isUserAdded ? "This removes your custom item."
                : "This removes this item and its reminders. Other accounts stay on your checklist. You can add it again from Review services.")
        }
        .sheet(isPresented: $showingAccountEditor) {
            if let move = task.move {
                if task.isUserAdded { CustomTaskView(move: move, task: task) }
                else { ServiceAccountEditorView(move: move, task: task) }
            }
        }
    }
}
