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

    // Neighborhood search state — destination
    @State private var destinationNeighborhoods: [NeighborhoodResult] = []
    @State private var selectedDestination: NeighborhoodResult? = nil
    @State private var isLoadingDestination = false
    @State private var destGeocodeTask: Task<Void, Never>? = nil
    /// True when a well-formed ZIP/postal code resolved to zero neighborhoods — the user
    /// can still continue (the app falls back to a ZIP-prefix centroid), but silently
    /// saying nothing left them with no idea their code wasn't recognized.
    @State private var destinationLookupFailed = false

    // Neighborhood search state — origin
    @State private var originNeighborhoods: [NeighborhoodResult] = []
    @State private var selectedOrigin: NeighborhoodResult? = nil
    @State private var isLoadingOrigin = false

    // Convenience accessors for saved names
    private var destinationLabel: String? { selectedDestination?.fullLabel }
    private var originLabel: String?      { selectedOrigin?.fullLabel }

    private var isCurrentStepValid: Bool {
        switch step {
        case 0: return true
        case 1: return Self.isValidPostalCode(destinationZip)
        case 2: return originZip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Self.isValidPostalCode(originZip)
        default: return false
        }
    }

    /// Accepts a 5-digit US ZIP or a 6-character Canadian postal code (letter-digit-letter
    /// -digit-letter-digit, e.g. "K1A 0B1"), space optional, case-insensitive. Both ZIP
    /// fields need this — a numeric-only keyboard plus a `count == 5` check previously
    /// made it impossible to type a Canadian code at all, even though the rest of the app
    /// (province detection, the Canadian catalog) already handles one correctly once entered.
    static func isValidPostalCode(_ raw: String) -> Bool {
        PostalCodeService.isValid(raw)
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
                removal:   .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.35), value: step)
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
        // Destination ZIP watcher
        .onChange(of: destinationZip) { _, newZip in
            selectedDestination = nil
            destinationNeighborhoods = []
            destinationLookupFailed = false
            destGeocodeTask?.cancel()
            guard Self.isValidPostalCode(newZip) else { isLoadingDestination = false; return }
            isLoadingDestination = true
            destGeocodeTask = Task {
                let results = await GeocoderService.neighborhoods(for: newZip)
                if !Task.isCancelled {
                    withAnimation(.spring(response: 0.4)) {
                        destinationNeighborhoods = results
                        // Auto-select if there's exactly one result
                        if results.count == 1 { selectedDestination = results.first }
                        isLoadingDestination = false
                        destinationLookupFailed = results.isEmpty
                    }
                }
            }
        }
        // Origin ZIP watcher
        .onChange(of: originZip) { _, newZip in
            selectedOrigin = nil
            originNeighborhoods = []
            guard Self.isValidPostalCode(newZip) else { isLoadingOrigin = false; return }
            isLoadingOrigin = true
            Task {
                let results = await GeocoderService.neighborhoods(for: newZip)
                withAnimation(.spring(response: 0.4)) {
                    originNeighborhoods = results
                    if results.count == 1 { selectedOrigin = results.first }
                    isLoadingOrigin = false
                }
            }
        }
    }

    // MARK: - Step 1: When?

    private var dateStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                Text("When's the\nday?")
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

                // Headline + resolved label
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where are you\nheaded?")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(4)

                    if let label = destinationLabel {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.accentPrimary)
                            Text(label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.accentPrimary)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // ZIP field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Destination ZIP code")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    TextField("e.g. 80202 or K1A 0B1", text: $destinationZip)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .padding(16)
                        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 16))
                        .onChange(of: destinationZip) { _, v in
                            // 7, not 6: a Canadian postal code plus its optional space.
                            if v.count > 7 { destinationZip = String(v.prefix(7)) }
                        }

                    if destinationLookupFailed {
                        Text("We couldn't recognize that code — double check it, or continue anyway and add your neighborhood later.")
                            .font(.system(size: 12.5))
                            .foregroundColor(Theme.priorityCritical)
                            .lineSpacing(2)
                            .transition(.opacity)
                    }
                }

                // Neighborhood picker
                neighborhoodPicker(
                    neighborhoods: destinationNeighborhoods,
                    selected: $selectedDestination,
                    isLoading: isLoadingDestination,
                    accentColor: Theme.accentPrimary
                )

                Text("Your ZIP gives us broad regional context for your move. It doesn't tell us which services your household uses — you choose what to add to your list.")
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

                    if let label = originLabel {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                            Text(label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current ZIP code (optional)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    TextField("e.g. 90210 or K1A 0B1", text: $originZip)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .padding(16)
                        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 16))
                        .onChange(of: originZip) { _, v in
                            if v.count > 7 { originZip = String(v.prefix(7)) }
                        }
                }

                // Neighborhood picker
                neighborhoodPicker(
                    neighborhoods: originNeighborhoods,
                    selected: $selectedOrigin,
                    isLoading: isLoadingOrigin,
                    accentColor: Theme.textSecondary
                )

                Text("Helps us remember accounts and services from your previous area. You can skip this and add it later in Move settings.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
                    .lineSpacing(2)
            }

            Spacer()

            HStack(spacing: 12) {
                backButton { retreat() }
                continueButton(Self.isValidPostalCode(originZip) ? "Let's go →" : "Skip for now →") {
                    completeIntake()
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    // MARK: - Neighborhood Chip Picker

    /// Renders the scrollable list of neighborhood chips.
    /// Only appears once a valid ZIP has been typed and results are ready.
    @ViewBuilder
    private func neighborhoodPicker(
        neighborhoods: [NeighborhoodResult],
        selected: Binding<NeighborhoodResult?>,
        isLoading: Bool,
        accentColor: Color
    ) -> some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                    .scaleEffect(0.8)
                Text("Finding neighborhoods…")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
            }
            .transition(.opacity)
        } else if neighborhoods.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Which neighborhood?")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(neighborhoods) { hood in
                            let isSelected = selected.wrappedValue?.id == hood.id
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3)) {
                                    selected.wrappedValue = isSelected ? nil : hood
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hood.neighborhood)
                                        .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? .black : Theme.textPrimary)

                                    // Show city context if neighborhood name differs from fullLabel
                                    let context = hood.fullLabel
                                        .replacingOccurrences(of: hood.neighborhood + ", ", with: "")
                                    if !context.isEmpty && context != hood.neighborhood {
                                        Text(context)
                                            .font(.system(size: 11))
                                            .foregroundColor(isSelected ? .black.opacity(0.6) : Theme.textTertiary)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    isSelected
                                        ? accentColor
                                        : Theme.backgroundElevated
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            isSelected ? accentColor : Color.white.opacity(0.06),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(
                                    color: isSelected ? accentColor.opacity(0.3) : .clear,
                                    radius: 6, x: 0, y: 3
                                )
                                .scaleEffect(isSelected ? 1.02 : 1.0)
                                .animation(.spring(response: 0.25), value: isSelected)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 4) // room for shadow
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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
            originZip: Self.isValidPostalCode(originZip) ? originZip : nil,
            originNeighborhood: selectedOrigin?.fullLabel,
            destinationZip: destinationZip,
            destinationNeighborhood: selectedDestination?.fullLabel,
            destinationStateBucket: state,
            destinationCityBucket: city,
            originLatitude: selectedOrigin?.coordinate?.latitude,
            originLongitude: selectedOrigin?.coordinate?.longitude,
            destinationLatitude: selectedDestination?.coordinate?.latitude,
            destinationLongitude: selectedDestination?.coordinate?.longitude
        )
        modelContext.insert(move)
        modelContext.saveOrLog()
        withAnimation(.easeInOut(duration: 0.5)) { onComplete() }
    }
}
