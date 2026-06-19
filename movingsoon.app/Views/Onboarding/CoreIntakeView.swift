// CoreIntakeView.swift — One question at a time onboarding
import SwiftUI
import SwiftData

struct CoreIntakeView: View {
    @Environment(\.modelContext) private var modelContext
    let onComplete: () -> Void

    @State private var step: Int = 0
    @State private var anchorDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var destinationZip: String = ""
    @State private var originZip: String = ""

    // Derived city preview
    private var destinationCity: String? {
        guard destinationZip.count == 5 else { return nil }
        let (state, city) = ZipBucketService.bucket(zip: destinationZip)
        if let city = city {
            return "\(city.replacingOccurrences(of: "_", with: " ").capitalized), \(state)"
        }
        return state
    }

    private var originCity: String? {
        guard originZip.count == 5 else { return nil }
        let (state, city) = ZipBucketService.bucket(zip: originZip)
        if let city = city {
            return "\(city.replacingOccurrences(of: "_", with: " ").capitalized), \(state)"
        }
        return state
    }

    private var isCurrentStepValid: Bool {
        switch step {
        case 0: return true // date always valid
        case 1: return destinationZip.count == 5
        case 2: return true // origin ZIP optional
        default: return false
        }
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            // Step indicator dots
            VStack {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == step ? Theme.accentPrimary : Theme.backgroundElevated)
                            .frame(width: i == step ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: step)
                    }
                }
                .padding(.top, 60)
                Spacer()
            }

            // Step content
            Group {
                switch step {
                case 0: dateStep
                case 1: destinationStep
                case 2: originStep
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.35), value: step)
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Step 1: When?

    private var dateStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                Text("When's the\nbig day?")
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(4)

                Text("We'll use this to prioritize your tasks and send smart reminders.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(3)

                DatePicker("", selection: $anchorDate, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .padding(16)
                    .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 16))
            }

            Spacer()

            continueButton("Set the date") { advance() }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    // MARK: - Step 2: Where to?

    private var destinationStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where are you\nheaded?")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(4)

                    if let city = destinationCity {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.accentPrimary)
                            Text(city)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.accentPrimary)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.4), value: destinationZip)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Destination ZIP code")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    TextField("e.g. 80202", text: $destinationZip)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .padding(16)
                        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 16))
                        .onChange(of: destinationZip) { _, v in
                            if v.count > 5 { destinationZip = String(v.prefix(5)) }
                        }
                }

                Text("US or Canadian ZIP — we'll filter your task list to your region.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
                    .lineSpacing(2)
            }

            Spacer()

            HStack(spacing: 12) {
                backButton { retreat() }
                continueButton("That's where →", enabled: isCurrentStepValid) { advance() }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    // MARK: - Step 3: Where from?

    private var originStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where are you\ncoming from?")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(4)

                    if let city = originCity {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                            Text(city)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.4), value: originZip)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current ZIP code (optional)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    TextField("e.g. 90210", text: $originZip)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .padding(16)
                        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 16))
                        .onChange(of: originZip) { _, v in
                            if v.count > 5 { originZip = String(v.prefix(5)) }
                        }
                }

                Text("Helps us find services you need to cancel or transfer from your current city.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
                    .lineSpacing(2)
            }

            Spacer()

            HStack(spacing: 12) {
                backButton { retreat() }
                continueButton(originZip.count == 5 ? "Let's go →" : "Skip for now →") {
                    completeIntake()
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    // MARK: - Shared button components

    @ViewBuilder
    private func continueButton(_ label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(enabled ? .black : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(enabled ? Theme.accentPrimary : Theme.backgroundElevated,
                             in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }

    @ViewBuilder
    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 54, height: 54)
                .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { step = min(step + 1, 2) }
    }

    private func retreat() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { step = max(step - 1, 0) }
    }

    private func completeIntake() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let (state, city) = ZipBucketService.bucket(zip: destinationZip)
        let move = Move(
            anchorDate: anchorDate,
            originZip: originZip.count == 5 ? originZip : nil,
            destinationZip: destinationZip,
            destinationStateBucket: state,
            destinationCityBucket: city
        )
        modelContext.insert(move)
        try? modelContext.save()
        withAnimation(.easeInOut(duration: 0.5)) { onComplete() }
    }
}
