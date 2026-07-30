// LifestyleInterviewView.swift — Simplified 3-screen lifestyle interview
import SwiftUI
import SwiftData

// MARK: - ViewModel

@Observable
final class LifestyleViewModel {
    var currentScreen: Int = 0
    let totalScreens = 3  // 3 simple screens instead of 7

    // Screen 1: Yes/No questions
    var hasKids: Bool = false
    var hasPets: Bool = false
    var ownsHome: Bool = false

    // Screen 2: Financial institutions
    var selectedInstitutions: Set<KnownInstitution> = []

    // Screen 3: Optional extras (expanded inline)
    var expandedCategories: Set<String> = []
    var extraChips: [String: [ChipSection]] = [:]

    init() {
        buildExtraChips()
    }

    func next() {
        if currentScreen < totalScreens - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { currentScreen += 1 }
        }
    }
    func back() {
        if currentScreen > 0 {
            withAnimation(.easeInOut(duration: 0.3)) { currentScreen -= 1 }
        }
    }

    // Core flags from yes/no answers
    var coreFlags: Set<LifestyleFlag> {
        var flags: Set<LifestyleFlag> = []
        if hasKids { flags.insert(.hasChildren) }
        if hasPets { flags.insert(.hasPets) }
        if ownsHome {
            flags.insert(.isOwning)
            flags.insert(.livesInHouseOrTownhouse)
        } else {
            flags.insert(.isRenting)
        }
        return flags
    }

    // All flags including extra selections
    var allActiveFlags: Set<LifestyleFlag> {
        var flags = coreFlags
        for sections in extraChips.values {
            for section in sections {
                flags.formUnion(section.chips.filter { $0.isSelected }.compactMap { $0.flag })
            }
        }
        return flags
    }

    func toggleExtraChip(_ chip: BubbleChip, in category: String) {
        guard let sections = extraChips[category] else { return }
        for (sIdx, section) in sections.enumerated() {
            if let cIdx = section.chips.firstIndex(where: { $0.id == chip.id }) {
                extraChips[category]?[sIdx].chips[cIdx].isSelected.toggle()
                return
            }
        }
    }

    // MARK: - Optional extra categories (shown on screen 3)

    private func buildExtraChips() {
        extraChips["shopping"] = [
            ChipSection(title: "Shopping & Delivery", chips: [
                BubbleChip(id: "usesAmazon",     label: "Amazon",       emoji: "📦", flag: .usesAmazon),
                BubbleChip(id: "usesTarget",     label: "Target",       emoji: "🎯", flag: .usesTarget),
                BubbleChip(id: "usesWalmart",    label: "Walmart",      emoji: "🛒", flag: .usesWalmart),
                BubbleChip(id: "usesCostco",     label: "Costco",       emoji: "🏬", flag: .usesCostco),
                BubbleChip(id: "usesDoorDash",   label: "DoorDash",     emoji: "🍕", flag: .usesDoorDash),
                BubbleChip(id: "usesUberEats",   label: "Uber Eats",    emoji: "🍔", flag: .usesUberEats),
                BubbleChip(id: "usesInstacart",  label: "Instacart",    emoji: "🛒", flag: .usesInstacart),
            ])
        ]

        extraChips["streaming"] = [
            ChipSection(title: "Streaming & Entertainment", chips: [
                BubbleChip(id: "netflix",     label: "Netflix",     emoji: "🎬", flag: .usesNetflix),
                BubbleChip(id: "hulu",        label: "Hulu",        emoji: "📺", flag: .usesHulu),
                BubbleChip(id: "disney",      label: "Disney+",     emoji: "✨", flag: .usesDisneyPlus),
                BubbleChip(id: "hbo",         label: "Max / HBO",   emoji: "🎭", flag: .usesHBOMax),
                BubbleChip(id: "spotify",     label: "Spotify",     emoji: "🎵", flag: .usesSpotify),
                BubbleChip(id: "gaming",      label: "Xbox / PS",   emoji: "🎮", flag: .usesGamingSubs),
                BubbleChip(id: "xfinity",     label: "Xfinity",     emoji: "📺", flag: .usesXfinity),
                BubbleChip(id: "spectrum",    label: "Spectrum",    emoji: "📺", flag: .usesSpectrum),
            ])
        ]

        extraChips["fitness"] = [
            ChipSection(title: "Fitness & Wellness", chips: [
                BubbleChip(id: "planetfitness", label: "Planet Fitness", emoji: "💪", flag: .usesPlanetFitness),
                BubbleChip(id: "ymca",          label: "YMCA",           emoji: "🏊", flag: .usesYMCA),
                BubbleChip(id: "peloton",       label: "Peloton",        emoji: "🚴", flag: .usesPeloton),
                BubbleChip(id: "localgym",      label: "Local Gym",      emoji: "🏋️", flag: .hasGymMembership),
            ])
        ]

        extraChips["transport"] = [
            ChipSection(title: "Getting Around", chips: [
                BubbleChip(id: "hasCar",        label: "Car",            emoji: "🚗", flag: .hasCar),
                BubbleChip(id: "hasEV",         label: "Electric Vehicle",emoji: "⚡", flag: .hasElectricVehicle),
                BubbleChip(id: "usesRideShare", label: "Uber / Lyft",    emoji: "🚕", flag: .usesRideShare),
                BubbleChip(id: "hasTollRoads",  label: "Toll Roads",     emoji: "🛣️", flag: .hasTollRoads),
                BubbleChip(id: "hasTSAPre",     label: "TSA PreCheck",   emoji: "🛂", flag: .hasTSAPreCheck),
            ])
        ]

        extraChips["life"] = [
            ChipSection(title: "Life & Finance", chips: [
                BubbleChip(id: "hasMortgage",     label: "Mortgage",         emoji: "🏡", flag: .hasMortgage),
                BubbleChip(id: "hasStudentLoans", label: "Student Loans",    emoji: "🎓", flag: .hasStudentLoans),
                BubbleChip(id: "isVeteran",       label: "Veteran",          emoji: "🎖️", flag: .isVeteran),
                BubbleChip(id: "hasMedicare",     label: "Medicare",         emoji: "⚕️", flag: .hasMedicare),
                BubbleChip(id: "isRetired",       label: "Retired",          emoji: "🌅", flag: .isRetired),
                BubbleChip(id: "runsBusiness",    label: "Own a Business",   emoji: "🏢", flag: .runsBusiness),
                BubbleChip(id: "crypto",          label: "Crypto",           emoji: "🪙", flag: .holdsCrypto),
            ])
        ]
    }
}

// MARK: - Container View

struct LifestyleInterviewView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    let onComplete: () -> Void

    @State private var vm: LifestyleViewModel

    init(move: Move, onComplete: @escaping () -> Void) {
        self.move = move
        self.onComplete = onComplete
        self._vm = State(initialValue: LifestyleViewModel())
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            // Progress dots
            VStack {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == vm.currentScreen ? Theme.accentPrimary : Theme.backgroundElevated)
                            .frame(width: i == vm.currentScreen ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: vm.currentScreen)
                    }
                }
                .padding(.top, 60)
                Spacer()
            }

            Group {
                switch vm.currentScreen {
                case 0: quickQuestionsScreen
                case 1: financialScreen
                case 2: optionalExtrasScreen
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.3), value: vm.currentScreen)
        }
    }

    // MARK: - Screen 1: Quick Yes/No questions

    private var quickQuestionsScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A few quick\nquestions")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(4)
                    Text("We'll use these to build your personalized task list.")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textSecondary)
                        .lineSpacing(3)
                }

                VStack(spacing: 12) {
                    YesNoCard(
                        question: "Kids at home?",
                        emoji: "👧",
                        isSelected: vm.hasKids,
                        onToggle: { vm.hasKids.toggle() }
                    )
                    YesNoCard(
                        question: "Pets?",
                        emoji: "🐾",
                        isSelected: vm.hasPets,
                        onToggle: { vm.hasPets.toggle() }
                    )
                    YesNoCard(
                        question: "Owning your new home?",
                        emoji: "🏡",
                        isSelected: vm.ownsHome,
                        onToggle: { vm.ownsHome.toggle() }
                    )
                }
            }

            Spacer()

            continueButton("Looks good →") { vm.next() }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    // MARK: - Screen 2: Financial accounts

    private var financialScreen: some View {
        FinancialScreenView(
            selectedInstitutions: Binding(
                get: { vm.selectedInstitutions },
                set: { vm.selectedInstitutions = $0 }
            ),
            stepIndex: 1,
            totalSteps: 3,
            stateBucket: move.originStateBucket ?? move.destinationStateBucket,
            onBack: { vm.back() },
            onFinish: { vm.next() }
        )
    }

    // MARK: - Screen 3: Optional extras

    private var optionalExtrasScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("We found")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(estimatedTaskCount)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.accentSuccess)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: estimatedTaskCount)
                        Text("tasks for you.")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Text("Want to add more?")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textSecondary)
                }

                // Category toggles
                let categories: [(id: String, label: String, emoji: String)] = [
                    ("shopping",  "Shopping & Delivery",      "📦"),
                    ("streaming", "Streaming & Cable",         "📺"),
                    ("fitness",   "Fitness & Wellness",        "💪"),
                    ("transport", "Vehicles & Travel",         "🚗"),
                    ("life",      "Life & Finance",            "💼"),
                ]

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(categories, id: \.id) { cat in
                            OptionalCategoryCard(
                                category: cat.id,
                                label: cat.label,
                                emoji: cat.emoji,
                                chips: vm.extraChips[cat.id] ?? [],
                                isExpanded: vm.expandedCategories.contains(cat.id),
                                onToggle: {
                                    withAnimation(.spring(response: 0.35)) {
                                        if vm.expandedCategories.contains(cat.id) {
                                            vm.expandedCategories.remove(cat.id)
                                        } else {
                                            vm.expandedCategories.insert(cat.id)
                                        }
                                    }
                                },
                                onChipTap: { chip in vm.toggleExtraChip(chip, in: cat.id) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 320)
            }

            Spacer()

            HStack(spacing: 12) {
                backButton { vm.back() }
                continueButton("Build my list →") { commitAndComplete() }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    private var estimatedTaskCount: Int {
        // Real count from the same generator that builds the actual checklist — updates
        // live as the user taps chips, and always matches what they land on at the dashboard.
        ChecklistGenerator.matchingItems(flags: vm.allActiveFlags).count + vm.selectedInstitutions.count
    }

    // MARK: - Shared components

    @ViewBuilder
    private func continueButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Theme.accentPrimary, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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

    // MARK: - Commit

    private func commitAndComplete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let profile = LifestyleProfile()
        profile.move = move
        var finalFlags = vm.allActiveFlags

        func applyRegionalFlags(for zip: String) {
            let clean = zip.replacingOccurrences(of: " ", with: "").uppercased()
            if clean.count == 6 && clean.first!.isLetter {
                finalFlags.insert(.isCanadian)
                switch clean.first! {
                case "A": finalFlags.insert(.inNewfoundland)
                case "B": finalFlags.insert(.inNovaScotia)
                case "C": finalFlags.insert(.inPEI)
                case "E": finalFlags.insert(.inNewBrunswick)
                case "G", "H", "J": finalFlags.insert(.inQuebec)
                case "K", "L", "M", "N", "P": finalFlags.insert(.inOntario)
                case "R": finalFlags.insert(.inManitoba)
                case "S": finalFlags.insert(.inSaskatchewan)
                case "T": finalFlags.insert(.inAlberta)
                case "V": finalFlags.insert(.inBritishColumbia)
                case "X": finalFlags.insert(.inNorthwestTerritories)
                case "Y": finalFlags.insert(.inYukon)
                default: break
                }
            } else if clean.count >= 5, Int(clean.prefix(2)) != nil {
                finalFlags.insert(.isAmerican)
            }
        }

        if let origin = move.originZip { applyRegionalFlags(for: origin) }
        applyRegionalFlags(for: move.destinationZip)

        profile.activeFlags = finalFlags
        modelContext.insert(profile)
        move.lifestyleProfile = profile

        var institutions: [FinancialInstitution] = []
        for known in vm.selectedInstitutions {
            let fi = FinancialInstitution(name: known.name, initials: known.initials,
                                          colorHex: known.colorHex, type: known.type,
                                          websiteURL: known.websiteURL)
            fi.move = move
            modelContext.insert(fi)
            move.institutions.append(fi)
            institutions.append(fi)
        }

        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: institutions)
        for task in tasks {
            task.move = move
            modelContext.insert(task)
        }
        move.tasks = tasks
        modelContext.saveOrLog()

        withAnimation(.easeInOut(duration: 0.4)) { onComplete() }
    }
}

// MARK: - Yes/No Card

struct YesNoCard: View {
    let question: String
    let emoji: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Theme.accentPrimary.opacity(0.15) : Theme.backgroundElevated,
                                in: RoundedRectangle(cornerRadius: 12))

                Text(question)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Theme.accentPrimary : Theme.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Theme.accentPrimary.opacity(0.08) : Theme.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Theme.accentPrimary.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Optional Category Card

struct OptionalCategoryCard: View {
    let category: String
    let label: String
    let emoji: String
    let chips: [ChipSection]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onChipTap: (BubbleChip) -> Void

    private var selectedCount: Int {
        chips.flatMap { $0.chips }.filter { $0.isSelected }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(emoji).font(.system(size: 20))
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    if selectedCount > 0 {
                        Text("\(selectedCount) selected")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.accentPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accentPrimary.opacity(0.12), in: Capsule())
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(chips) { section in
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(section.chips) { chip in
                                Button {
                                    onChipTap(chip)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(chip.emoji).font(.system(size: 14))
                                        Text(chip.label)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(chip.isSelected ? .white : Theme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        chip.isSelected ? Theme.accentPrimary : Theme.backgroundElevated,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.15), value: chip.isSelected)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selectedCount > 0 ? Theme.accentPrimary.opacity(0.3) : Theme.hairline, lineWidth: 1)
        )
    }
}
