// DashboardView.swift — All Tasks sheet, unified with main dashboard UX
import SwiftUI
import SwiftData

struct DashboardView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @State private var filter: TaskFilter = .pending
    @State private var searchText: String = ""

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
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.accentPrimary)
                            Text("\(move.completedCount) of \(move.totalCount) updated")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
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
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("done")
                                    .font(.system(size: 8))
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
                        .font(.system(size: 14))
                    TextField("Search tasks...", text: $searchText)
                        .font(.system(size: 14))
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
                                        .font(.system(size: 13, weight: filter == tab ? .semibold : .regular))
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
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
                            .font(.system(size: 40))
                        Text(emptyStateMessage)
                            .font(.system(size: 16, weight: .medium))
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
    }

    // MARK: - Helpers

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
            try? modelContext.save()
        }
    }
}

// MARK: - Unified Task Row

struct UnifiedTaskRow: View {
    let task: ChecklistTask
    let moveDate: Date
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

            // Completion ring
            Button(action: onComplete) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(task.status == .completed ? Theme.accentSuccess :
                                     isOverdue ? Theme.accentPrimary :
                                     Theme.textSecondary.opacity(0.4))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            // Icon
            if let emoji = task.institutionInitials, task.institutionName == nil {
                Text(emoji).font(.system(size: 22)).frame(width: 36, height: 36)
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
                    Text(task.category.emoji).font(.system(size: 16))
                }
                .frame(width: 36, height: 36)
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(task.status == .completed ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(task.status == .completed, color: Theme.textTertiary)
                    .lineLimit(2)
                Text(task.institutionName ?? task.category.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(task.status == .completed ? Theme.accentSuccess.opacity(0.6) : Theme.textTertiary)
            }

            Spacer()

            // Due label
            if let label = dueLabel {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isOverdue ? Theme.accentPrimary : Theme.textTertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((isOverdue ? Theme.accentPrimary : Color.white).opacity(0.08), in: Capsule())
            }

            // Deep link
            if let url = task.deepLinkURL, task.status != .completed {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.accentPrimary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(task.isHeroItem && task.status != .completed ? Theme.uspsBlue.opacity(0.08) : Color.clear)
    }
}
