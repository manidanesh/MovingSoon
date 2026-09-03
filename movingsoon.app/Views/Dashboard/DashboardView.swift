// DashboardView.swift — All Tasks sheet, unified with main dashboard UX
import SwiftUI
import SwiftData

struct DashboardView: View {
    let move: Move
    /// Set when arriving from a Category Progress Rail chip tap — restricts the list
    /// to that one category on top of whatever TaskFilter tab is selected, so "which
    /// category am I behind on" (the rail's whole point) actually leads somewhere.
    var categoryFilter: TaskCategory? = nil
    /// Fired after a task is deleted (Not Applicable) so the presenting screen
    /// can resync notifications/geofences — this sheet doesn't own those
    /// services itself. Defaults to a no-op so existing call sites still compile.
    var onTaskRemoved: (ChecklistTask) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @State private var filter: TaskFilter = .pending
    @State private var searchText: String = ""
    // Circle tap opens this instead of completing instantly — same reasoning as the
    // main dashboard's TaskActionSheet: a single tap shouldn't silently close a task
    // out from under the user with no chance to see what it is or pick "Update Now"
    // vs. "Mark as Done" first.
    @State private var selectedTask: ChecklistTask? = nil

    enum TaskFilter: String, CaseIterable {
        case pending   = "Pending"
        case overdue   = "Overdue"
        case critical  = "Critical"
        case completed = "Completed"
    }

    private var allTasks: [ChecklistTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let moveDay = calendar.startOfDay(for: move.anchorDate)

        var tasks: [ChecklistTask]
        switch filter {
        case .pending:
            tasks = move.tasks.filter { $0.status != .completed }
        case .overdue:
            tasks = move.tasks.filter { task in
                guard task.status != .completed else { return false }
                // Post-move tasks (positive tMinusDays) are only overdue once move date has passed
                if task.tMinusDays > 0 && today <= moveDay { return false }
                let due = calendar.date(byAdding: .day, value: task.tMinusDays, to: move.anchorDate) ?? move.anchorDate
                return calendar.startOfDay(for: due) < today
            }
        case .critical:
            tasks = move.tasks.filter { $0.priority == .critical && $0.status != .completed }
        case .completed:
            tasks = move.tasks.filter { $0.status == .completed }
        }

        if let categoryFilter {
            tasks = tasks.filter { $0.category == categoryFilter }
        }

        // Search filter
        if !searchText.isEmpty {
            tasks = tasks.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.institutionName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        return tasks.sorted { $0.tMinusDays < $1.tMinusDays }
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Progress Header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(move.personaKey.tagline)
                                .themeText(12, weight: .medium)
                                .foregroundColor(Theme.accentPrimary)
                            Text("\(move.completedCount) of \(move.totalCount) updated")
                                .themeRounded(20, weight: .bold)
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(Theme.backgroundElevated, lineWidth: 5)
                            Circle()
                                .trim(from: 0, to: move.completionFraction)
                                .stroke(Theme.accentSuccess,
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: move.completionFraction)
                            VStack(spacing: 0) {
                                Text("\(Int(move.completionFraction * 100))%")
                                    .themeRounded(13, weight: .bold)
                                    .foregroundColor(Theme.textPrimary)
                                Text("done")
                                    .themeText(8)
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .frame(width: 54, height: 54)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.backgroundElevated).frame(height: 5)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Theme.accentPrimary, Theme.accentSuccess],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * move.completionFraction, height: 5)
                                .animation(.easeInOut(duration: 0.5), value: move.completionFraction)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // MARK: Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textTertiary)
                        .themeText(14)
                    TextField("Search tasks...", text: $searchText)
                        .themeText(14)
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // MARK: Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TaskFilter.allCases, id: \.self) { tab in
                            let count = countFor(tab)
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { filter = tab }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tab.rawValue)
                                        .themeText(13, weight: filter == tab ? .semibold : .regular)
                                    if count > 0 {
                                        Text("\(count)")
                                            .themeRounded(11, weight: .bold)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(filter == tab ? Color.black.opacity(0.25) : Theme.backgroundElevated,
                                                        in: Capsule())
                                    }
                                }
                                .foregroundColor(filter == tab ? .black : Theme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(filter == tab ? Theme.accentPrimary : Theme.backgroundElevated,
                                            in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)

                Rectangle().fill(Theme.hairline).frame(height: 0.5)

                // MARK: Task List
                if allTasks.isEmpty {
                    VStack(spacing: 12) {
                        Text(emptyStateEmoji)
                            .themeText(40)
                        Text(emptyStateMessage)
                            .themeText(16, weight: .medium)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(allTasks) { task in
                                UnifiedTaskRow(
                                    task: task,
                                    moveDate: move.anchorDate,
                                    onTap: { selectedTask = task },
                                    onComplete: { toggleTask(task) }
                                )
                                Rectangle().fill(Theme.hairline).frame(height: 0.5)
                                    .padding(.leading, 68)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .dynamicTypeSize(...(.accessibility1))
        .sheet(item: $selectedTask) { task in
            TaskActionSheet(
                task: task,
                onAlreadyDone: {
                    toggleTask(task)
                    selectedTask = nil
                },
                onUpdateNow: {
                    // Opens the link only — does not auto-complete, matching the main
                    // dashboard's Update Now, which likewise only starts the process.
                    if let url = task.deepLinkURL {
                        UIApplication.shared.open(url)
                    }
                    selectedTask = nil
                },
                onLater: { selectedTask = nil },
                onNotApplicable: {
                    removeTaskNotApplicable(task)
                    selectedTask = nil
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Helpers

    /// A real deletion, not a status change — see TaskActionSheet.onNotApplicable
    /// for why (catalog tasks like Mathnasium/Goldfish Swim School get matched
    /// from broad lifestyle flags that can't know which activities a family
    /// actually uses, so a wrong match needs a permanent way out).
    private func removeTaskNotApplicable(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation {
            move.tasks.removeAll { $0.id == task.id }
            modelContext.delete(task)
            modelContext.saveOrLog()
        }
        onTaskRemoved(task)
    }

    private func countFor(_ tab: TaskFilter) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let moveDay = calendar.startOfDay(for: move.anchorDate)
        switch tab {
        case .pending:   return move.tasks.filter { $0.status != .completed }.count
        case .overdue:
            return move.tasks.filter { task in
                guard task.status != .completed else { return false }
                if task.tMinusDays > 0 && today <= moveDay { return false }
                let due = calendar.date(byAdding: .day, value: task.tMinusDays, to: move.anchorDate) ?? move.anchorDate
                return calendar.startOfDay(for: due) < today
            }.count
        case .critical:  return move.tasks.filter { $0.priority == .critical && $0.status != .completed }.count
        case .completed: return move.tasks.filter { $0.status == .completed }.count
        }
    }

    private var emptyStateEmoji: String {
        switch filter {
        case .pending:   return "✅"
        case .overdue:   return "🎉"
        case .critical:  return "✅"
        case .completed: return "📋"
        }
    }

    private var emptyStateMessage: String {
        switch filter {
        case .pending:   return searchText.isEmpty ? "All caught up!" : "No tasks match \"\(searchText)\""
        case .overdue:   return "No overdue tasks — great work!"
        case .critical:  return "No critical tasks remaining"
        case .completed: return "No completed tasks yet"
        }
    }

    private func toggleTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation {
            if task.status == .completed {
                task.resetStatus()
            } else {
                task.advanceStatus()
                if task.status == .pendingVerification { task.advanceStatus() }
            }
            modelContext.saveOrLog()
        }
    }
}

// MARK: - Unified Task Row

struct UnifiedTaskRow: View {
    let task: ChecklistTask
    let moveDate: Date
    /// Circle tap on a pending task opens the action sheet — it never completes the
    /// task directly. Only an already-completed task's checkmark reacts to onComplete,
    /// as an undo.
    let onTap: () -> Void
    let onComplete: () -> Void

    private var dueLabel: String? {
        let cal = Calendar.current
        let dueDate = cal.date(byAdding: .day, value: task.tMinusDays, to: moveDate) ?? moveDate
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                       to: cal.startOfDay(for: dueDate)).day ?? 0
        if task.status == .completed { return nil }
        if days < 0  { return "Overdue" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days <= 7 { return "In \(days)d" }
        return nil
    }

    private var isOverdue: Bool {
        guard task.status != .completed else { return false }
        // Post-move tasks not overdue until move date has passed
        let today = Calendar.current.startOfDay(for: Date())
        let moveDay = Calendar.current.startOfDay(for: moveDate)
        if task.tMinusDays > 0 && today <= moveDay { return false }
        let dueDate = Calendar.current.date(byAdding: .day, value: task.tMinusDays, to: moveDate) ?? moveDate
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        HStack(spacing: 14) {

            // Status only for pending tasks — not a button. A circle signifies
            // "tap to toggle directly," same as Reminders/Things; using that shape
            // to instead open a 3-choice menu breaks that trained mapping. The row
            // content (below) is the actual call to action. Completed tasks keep a
            // real, direct-toggle checkmark, which a checkbox shape correctly signifies.
            if task.status == .completed {
                Button(action: onComplete) {
                    Image(systemName: "checkmark.circle.fill")
                        .themeText(22)
                        .foregroundColor(Theme.accentSuccess)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark \(task.title) not complete")
            } else {
                Image(systemName: "circle")
                    .themeText(22)
                    .foregroundColor(isOverdue ? Theme.priorityCritical : task.priority.color.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            }

            // Icon
            if let emoji = task.institutionInitials, task.institutionName == nil {
                Text(emoji).themeText(22).frame(width: 36, height: 36)
            } else if task.institutionName != nil {
                InstitutionBadgeView(
                    initials: task.institutionInitials ?? "?",
                    colorHex: task.institutionColorHex ?? "#626567",
                    size: 36
                )
            } else {
                ZStack {
                    Circle()
                        .fill(Color(hex: task.institutionColorHex ?? "#626567").opacity(0.15))
                    Text(task.category.emoji).themeText(16)
                }
                .frame(width: 36, height: 36)
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .themeText(14, weight: .medium)
                    .foregroundColor(task.status == .completed ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(task.status == .completed, color: Theme.textTertiary)
                    .lineLimit(2)
                Text(task.institutionName ?? task.category.rawValue)
                    .themeText(12)
                    .foregroundColor(task.status == .completed ? Theme.accentSuccess.opacity(0.6) : Theme.textTertiary)
            }

            Spacer()

            // Due label
            if let label = dueLabel {
                Text(label)
                    .themeText(10, weight: .semibold)
                    .foregroundColor(isOverdue ? Theme.priorityCritical : Theme.textTertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((isOverdue ? Theme.priorityCritical : Color.white).opacity(0.08), in: Capsule())
            }

            // Deep link — a distinct, explicitly link-shaped affordance, separate
            // from the row's own "open the action sheet" tap target below.
            if let url = task.deepLinkURL, task.status != .completed {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .themeText(18)
                        .foregroundColor(Theme.accentPrimary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(task.institutionName ?? task.title) website")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(task.isHeroItem && task.status != .completed ? Theme.uspsBlue.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if task.status != .completed { onTap() }
        }
        // Shared with ZenMilestoneTaskRow in ZenDashboardView.swift — see that
        // type's doc comment for why only the pending row combines.
        .modifier(CombinedAccessibilityIfPending(task: task))
    }
}
