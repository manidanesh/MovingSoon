// TaskRowView.swift — Individual task item with institution badge or category icon
import SwiftUI

struct TaskRowView: View {
    @Bindable var task: ChecklistTask
    @State private var showingUndo = false

    var body: some View {
        HStack(spacing: 12) {

            // MARK: Momentum ring
            Button {
                withAnimation(.spring(duration: 0.35)) { task.advanceStatus() }
                if task.status == .completed {
                    showingUndo = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingUndo = false }
                }
            } label: {
                MomentumRingView(status: task.status, size: 32)
            }
            .buttonStyle(.plain)

            // MARK: Icon — emoji for catalog tasks, colored badge for institutions
            if let raw = task.institutionInitials {
                if task.institutionName != nil {
                    // Real institution (bank/card) → colored badge with initials
                    InstitutionBadgeView(initials: raw,
                                         colorHex: task.institutionColorHex ?? "#626567",
                                         size: 36)
                } else {
                    // Catalog task → emoji in tinted circle
                    ZStack {
                        Circle()
                            .fill(Color(hex: task.institutionColorHex ?? "#626567").opacity(0.2))
                        Text(raw)
                            .font(.system(size: 18))
                    }
                    .frame(width: 36, height: 36)
                }
            } else {
                CategoryIconView(category: task.category, size: 36)
            }

            // MARK: Title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(task.status == .completed ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(task.status == .completed, color: Theme.textTertiary)
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.2), value: task.status)

                // Institution name OR category
                Text(task.institutionName ?? task.category.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(statusSubtitleColor)
            }

            Spacer()

            // MARK: Deep link arrow
            if let url = task.deepLinkURL, task.status != .completed {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.accentPrimary.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(task.isHeroItem ? Theme.uspsBlue.opacity(0.1) : Color.clear)
        .overlay(alignment: .bottom) {
            if !task.isHeroItem {
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
            }
        }
        .overlay(alignment: .bottom) {
            if showingUndo {
                UndoChip { withAnimation { task.resetStatus(); showingUndo = false } }
                    .padding(.bottom, -36)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var statusSubtitleColor: Color {
        switch task.status {
        case .toDo:                return Theme.textTertiary
        case .pendingVerification: return Theme.accentPending
        case .completed:           return Theme.accentSuccess
        }
    }
}

private struct UndoChip: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Undo", systemImage: "arrow.uturn.backward")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.backgroundElevated, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
