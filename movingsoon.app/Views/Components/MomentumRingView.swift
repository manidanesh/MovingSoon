// MomentumRingView.swift — 3-state progress ring for task items
import SwiftUI

struct MomentumRingView: View {
    let status: TaskStatus
    let size: CGFloat

    init(status: TaskStatus, size: CGFloat = 32) {
        self.status = status
        self.size = size
    }

    private var ringColor: Color {
        switch status {
        case .toDo:                return Theme.backgroundElevated
        case .pendingVerification: return Theme.accentPending
        case .completed:           return Theme.accentSuccess
        }
    }

    private var fillFraction: Double {
        switch status {
        case .toDo:                return 0.0
        case .pendingVerification: return 0.5
        case .completed:           return 1.0
        }
    }

    private var innerIcon: String? {
        switch status {
        case .toDo:                return nil
        case .pendingVerification: return "clock.fill"
        case .completed:           return "checkmark"
        }
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Theme.backgroundElevated, lineWidth: 3)
                .frame(width: size, height: size)

            // Fill arc
            Circle()
                .trim(from: 0, to: fillFraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(.easeInOut(duration: 0.4), value: fillFraction)

            // Inner icon
            if let icon = innerIcon {
                Image(systemName: icon)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(ringColor)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: status)
    }
}
