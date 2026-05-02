// BubblePickerView.swift — Reusable emoji chip grid for lifestyle interview
import SwiftUI

struct BubbleChip: Identifiable, Hashable {
    let id: String
    let label: String
    let emoji: String
    let flag: LifestyleFlag?
    var isSelected: Bool = false

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: BubbleChip, r: BubbleChip) -> Bool { l.id == r.id }
}

struct ChipSection: Identifiable {
    let id = UUID()
    let title: String
    var chips: [BubbleChip]
}

struct BubblePickerView: View {
    let sections: [ChipSection]
    let onToggle: (BubbleChip) -> Void

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            ForEach(sections) { section in
                if !section.chips.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        if !section.title.isEmpty {
                            Text(section.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .padding(.horizontal, 24)
                        }
                        
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(section.chips) { chip in
                                ChipView(chip: chip) { onToggle(chip) }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}

private struct ChipView: View {
    let chip: BubbleChip
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(chip.emoji)
                    .font(.system(size: 20))
                Text(chip.label)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(chip.isSelected ? .white : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if chip.isSelected {
                    Circle()
                        .fill(Theme.accentPrimary)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(chip.isSelected ? Theme.accentPrimary.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                chip.isSelected ? Theme.accentPrimary.opacity(0.6) : Theme.hairline,
                                lineWidth: chip.isSelected ? 1 : 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(chip.isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chip.isSelected)
    }
}

// MARK: - Interview Screen Template

struct InterviewScreenView<Content: View>: View {
    let emoji: String
    let title: String
    let subtitle: String
    let stepIndex: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onNext: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Hairline Progress
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.accentPrimary)
                            .frame(width: geo.size.width * CGFloat(stepIndex + 1) / CGFloat(totalSteps))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: stepIndex)
                    }
                }
                .frame(height: 1)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Text("\(stepIndex + 1) / \(totalSteps)")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(Theme.textTertiary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                        // Title block (Editorial Typography)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(emoji).font(.system(size: 32)).padding(.horizontal, 24)
                            Text(title)
                                .font(.system(size: 30, weight: .semibold, design: .serif))
                                .foregroundColor(Theme.textPrimary)
                                .padding(.horizontal, 24)
                            Text(subtitle)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(4)
                                .padding(.horizontal, 24)
                        }

                        content()
                            .padding(.bottom, 140)
                    }
                }
            }
            .background(Theme.backgroundPrimary.ignoresSafeArea())

            // Floating Continue Pill
            Button(action: onNext) {
                HStack(spacing: 8) {
                    Text("Continue")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Theme.accentPrimary)
                        .shadow(color: Theme.accentPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 32)
        }
    }
}
