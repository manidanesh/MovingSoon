// DashboardView.swift — Main action hub
import SwiftUI
import SwiftData

struct DashboardView: View {
    let move: Move
    @State private var expandedBuckets: Set<TaskPriority> = [.critical, .high]

    private var heroTask: ChecklistTask? {
        move.tasks.first { $0.isHeroItem }
    }

    private var nonHeroTasks: [ChecklistTask] {
        move.tasks.filter { !$0.isHeroItem }
    }

    private var tasksByPriority: [(priority: TaskPriority, tasks: [ChecklistTask])] {
        TaskPriority.allCases.compactMap { priority in
            let tasks = nonHeroTasks
                .filter { $0.priority == priority }
                .sorted { $0.tMinusDays < $1.tMinusDays }
            return tasks.isEmpty ? nil : (priority, tasks)
        }
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: Header
                    DashboardHeaderView(move: move)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // MARK: USPS Hero
                    if let hero = heroTask {
                        HeroUSPSView(task: hero)
                            .padding(.horizontal, 20)
                    }

                    // MARK: Task buckets
                    ForEach(tasksByPriority, id: \.priority) { bucket in
                        TaskBucketSection(
                            priority: bucket.priority,
                            tasks: bucket.tasks,
                            isExpanded: expandedBuckets.contains(bucket.priority)
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if expandedBuckets.contains(bucket.priority) {
                                    expandedBuckets.remove(bucket.priority)
                                } else {
                                    expandedBuckets.insert(bucket.priority)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
    }
}

// MARK: - Dashboard Header

struct DashboardHeaderView: View {
    let move: Move

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(move.personaKey.tagline)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.accentPrimary)

                    Text(daysLabel)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                // Overall completion ring
                ZStack {
                    Circle()
                        .stroke(Theme.backgroundElevated, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: move.completionFraction)
                        .stroke(Theme.accentSuccess, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: move.completionFraction)
                    VStack(spacing: 0) {
                        Text("\(Int(move.completionFraction * 100))%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text("done")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                .frame(width: 64, height: 64)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.backgroundElevated).frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(colors: [Theme.accentPrimary, Theme.accentSuccess],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * move.completionFraction, height: 6)
                        .animation(.easeInOut(duration: 0.5), value: move.completionFraction)
                }
            }
            .frame(height: 6)

            Text("\(move.completedCount) of \(move.totalCount) updates complete")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(18)
        .background(Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 0.5)
        }
    }

    private var daysLabel: String {
        let days = move.daysUntilMove
        if days > 0  { return "T-minus \(days) days" }
        if days == 0 { return "Moving day! 🎉" }
        return "Day \(abs(days)) in your new home"
    }
}

// MARK: - Task Bucket Section

struct TaskBucketSection: View {
    let priority: TaskPriority
    let tasks: [ChecklistTask]
    let isExpanded: Bool
    let onToggle: () -> Void

    private var incomplete: Int { tasks.filter { $0.status != .completed }.count }
    private var priorityColor: Color {
        switch priority {
        case .critical: return Theme.priorityCritical
        case .high:     return Theme.priorityHigh
        case .medium:   return Theme.priorityMedium
        case .low:      return Theme.priorityLow
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack {
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 8, height: 8)

                    Text(priority.bucketLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Text("\(incomplete) left")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(Theme.backgroundElevated)

                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        TaskRowView(task: task)
                    }
                }
                .padding(12)
            }
        }
        .background(Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 0.5)
        }
    }
}
