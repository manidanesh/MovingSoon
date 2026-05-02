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

                // MARK: Back / step counter
                HStack {
                    if stepNumber > 1 {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .padding(10)
                                .background(Theme.backgroundElevated, in: Circle())
                        }
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
                            .font(.system(size: 44))
                            .padding(.top, 32)

                        // MARK: Title
                        Text(title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.top, 16)
                            .fixedSize(horizontal: false, vertical: true)

                        // MARK: Subtitle
                        Text(subtitle)
                            .font(.system(size: 16))
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
                            .font(.system(size: 17, weight: .semibold))
                        if stepNumber < totalSteps {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
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
