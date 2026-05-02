// SelectionCard.swift — Reusable pill/card selection component for onboarding
import SwiftUI

struct SelectionCard: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    init(_ label: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.label = label; self.icon = icon; self.isSelected = isSelected; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .white : Theme.textSecondary)
                        .frame(width: 24)
                }
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : Theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Theme.accentPrimary : Theme.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? Theme.accentPrimary : Theme.backgroundElevated,
                                lineWidth: 1.5
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
