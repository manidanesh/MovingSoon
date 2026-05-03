// LocationConsentCard.swift — 30-day location consent prompt shown on ZenDashboardView
import SwiftUI

struct LocationConsentCard: View {
    let onAllow: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: Header row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accentPrimary.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Theme.accentPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart Reminders")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.accentPrimary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                    Text("30-day location access")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                }

                Spacer()

                // Dismiss X
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                        .padding(8)
                        .background(Theme.backgroundElevated, in: Circle())
                }
                .buttonStyle(.plain)
            }

            // MARK: Body copy
            Text("Give us access for 30 days — we'll notify you when you're near a place that needs your new address.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // MARK: Actions
            HStack(spacing: 10) {
                // Primary — Allow
                Button(action: onAllow) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Allow 30 Days")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accentPrimary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // Secondary — Not Now
                Button(action: onDismiss) {
                    Text("Not Now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.accentPrimary.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LocationConsentCard(
            onAllow: { print("Allow tapped") },
            onDismiss: { print("Dismiss tapped") }
        )
        .padding(24)
    }
    .preferredColorScheme(.dark)
}
