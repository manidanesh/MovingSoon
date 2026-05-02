// HeroUSPSView.swift — Pinned USPS card at the top of the dashboard
import SwiftUI

struct HeroUSPSView: View {
    @Bindable var task: ChecklistTask

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Header bar
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.white)
                Text("USPS Mail Forwarding")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                // Status badge
                Text(task.status.rawValue.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2), in: Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Theme.uspsBlue)

            // MARK: Body
            VStack(alignment: .leading, spacing: 12) {
                Text("The #1 step — do this first.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text("⚠️ Only use the official USPS site. Third-party sites charge up to $40 for a service that costs $1.10.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    // Deep link
                    if let url = task.deepLinkURL {
                        Link(destination: url) {
                            Label("Open USPS →", systemImage: "arrow.up.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Theme.uspsBlue, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Advance state button
                    if task.status != .completed {
                        Button {
                            withAnimation(.spring(duration: 0.35)) {
                                task.advanceStatus(method: .manualConfirm)
                            }
                        } label: {
                            Label(
                                task.status == .toDo ? "Mark Started" : "Mark Done ✓",
                                systemImage: task.status == .toDo ? "clock.fill" : "checkmark.circle.fill"
                            )
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(task.status == .toDo ? Theme.accentPending : Theme.accentSuccess)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                (task.status == .toDo ? Theme.accentPending : Theme.accentSuccess).opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .background(Theme.backgroundCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.uspsBlue.opacity(0.5), lineWidth: 1.5)
        )
    }

    private var statusColor: Color {
        switch task.status {
        case .toDo:                return Theme.priorityCritical
        case .pendingVerification: return Theme.accentPending
        case .completed:           return Theme.accentSuccess
        }
    }
}
