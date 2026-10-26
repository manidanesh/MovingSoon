// OnboardingStepTemplate.swift — Shared layout for all 7 onboarding steps
import SwiftUI

struct OnboardingStepTemplate<Content: View>: View {
    let stepNumber: Int
    let totalSteps: Int
    let icon: String
    let title: String
    let subtitle: String
    let canProceed: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.backgroundElevated).frame(height: 3)
                        Capsule()
                            .fill(Theme.accentPrimary)
                            .frame(width: geo.size.width * Double(stepNumber) / Double(totalSteps), height: 3)
                            .animation(.easeInOut(duration: 0.4), value: stepNumber)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .accessibilityHidden(true)

                // MARK: Back / step counter
                HStack {
                    if stepNumber > 1 {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .themeText(17, weight: .semibold)
                                .foregroundColor(Theme.textSecondary)
                                .frame(minWidth: 44, minHeight: 44)
                                .padding(10)
                                .background(Theme.backgroundElevated, in: Circle())
                        }
                        .accessibilityLabel("Back")
                    }
                    Spacer()
                    Text("\(stepNumber) of \(totalSteps)")
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Icon
                        Text(icon)
                            .themeText(44, weight: .regular)
                            .padding(.top, 32)
                            .accessibilityHidden(true)

                        // MARK: Title
                        Text(title)
                            .themeRounded(30, weight: .bold)
                            .foregroundColor(Theme.textPrimary)
                            .padding(.top, 16)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        // MARK: Subtitle
                        Text(subtitle)
                            .themeText(16, weight: .regular)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.top, 8)
                            .fixedSize(horizontal: false, vertical: true)

                        // MARK: Step content
                        content()
                            .padding(.top, 32)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }

                Spacer(minLength: 0)

                // MARK: Continue button
                Button(action: onNext) {
                    HStack {
                        Text(stepNumber == totalSteps ? "Let's Go →" : "Continue")
                            .themeText(17, weight: .semibold)
                        if stepNumber < totalSteps {
                            Image(systemName: "arrow.right")
                                .themeText(14, weight: .semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(canProceed ? Theme.accentPrimary : Theme.backgroundElevated)
                    .foregroundColor(canProceed ? .white : Theme.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .animation(.easeInOut(duration: 0.2), value: canProceed)
                }
                .disabled(!canProceed)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
