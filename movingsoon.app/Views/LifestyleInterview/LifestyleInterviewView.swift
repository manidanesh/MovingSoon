// LifestyleInterviewView.swift — 6-screen lifestyle interview + financial account picker
import SwiftUI
import SwiftData

@Observable
final class LifestyleViewModel {
    var chips: [String: [ChipSection]] = [:]
    var currentScreen: Int = 0
    let totalScreens = 7  // 6 lifestyle + 1 financial

    // Financial institutions
    var selectedInstitutions: Set<KnownInstitution> = []

    init(originZip: String?) { buildChips(originZip: originZip ?? "") }

    func toggle(chip: BubbleChip, in screen: String) {
        guard let sections = chips[screen] else { return }
        for (sIdx, section) in sections.enumerated() {
            if let cIdx = section.chips.firstIndex(where: { $0.id == chip.id }) {
                chips[screen]?[sIdx].chips[cIdx].isSelected.toggle()
                return
            }
        }
    }

    func activeFlags(in screen: String) -> Set<LifestyleFlag> {
        var flags: Set<LifestyleFlag> = []
        for section in chips[screen] ?? [] {
            flags.formUnion(section.chips.filter { $0.isSelected }.compactMap { $0.flag })
        }
        return flags
    }

    var allActiveFlags: Set<LifestyleFlag> {
        var flags: Set<LifestyleFlag> = []
        for sections in chips.values {
            for section in sections {
                flags.formUnion(section.chips.filter { $0.isSelected }.compactMap { $0.flag })
            }
        }
        return flags
    }

    func next() { if currentScreen < totalScreens - 1 { withAnimation(.easeInOut(duration: 0.3)) { currentScreen += 1 } } }
    func back() { if currentScreen > 0 { withAnimation(.easeInOut(duration: 0.3)) { currentScreen -= 1 } } }

    // MARK: - Chip definitions

    private func buildChips(originZip: String) {
        let regional = RegionalIntelligenceService.availableRegionalChips(forZip: originZip)
        let regionalIDs = RegionalIntelligenceService.regionalChipIDs
        
        func isAvailable(_ id: String) -> Bool {
            !regionalIDs.contains(id) || regional.contains(id)
        }
        
        // 1. Transport
        chips["transport"] = [
            ChipSection(title: "Vehicles", chips: [
                BubbleChip(id: "hasCar",         label: "Car",            emoji: "🚗", flag: .hasCar),
                BubbleChip(id: "hasEV",          label: "Electric Vehicle",emoji: "⚡", flag: .hasElectricVehicle),
                BubbleChip(id: "hasMotorcycle",  label: "Motorcycle",     emoji: "🏍️", flag: .hasMotorcycle),
                BubbleChip(id: "hasMultipleCars",label: "Multiple Cars",  emoji: "🚙", flag: .hasMultipleCars),
            ]),
            ChipSection(title: "Commute & Travel", chips: [
                BubbleChip(id: "hasBike",        label: "E-Bike / Scooter",emoji:"🛴", flag: .hasBike),
                BubbleChip(id: "usesRideShare",  label: "Uber / Lyft",    emoji: "🚕", flag: .usesRideShare),
                BubbleChip(id: "hasTollRoads",   label: "Toll Roads",     emoji: "🛣️", flag: .hasTollRoads),
                BubbleChip(id: "frequentTravel", label: "Frequent Traveler",emoji: "✈️", flag: .frequentTraveler),
                BubbleChip(id: "hasTSAPre",      label: "TSA PreCheck",   emoji: "🛂", flag: .hasTSAPreCheck),
                BubbleChip(id: "needsParking",   label: "Parking Permit", emoji: "🅿️", flag: .needsParkingPermit),
                BubbleChip(id: "airlineLoyalty", label: "Airline Loyalty",emoji: "✈️", flag: .hasAirlineLoyalty),
            ])
        ]
        
        // 2. Household
        chips["household"] = [
            ChipSection(title: "Family & Pets", chips: [
                BubbleChip(id: "hasPartner",   label: "Partner / Spouse",    emoji: "💑", flag: .hasPartner),
                BubbleChip(id: "hasChildren",  label: "Kids at Home",         emoji: "🧒", flag: .hasChildren),
                BubbleChip(id: "hasPets",      label: "Pets",                 emoji: "🐾", flag: .hasPets),
                BubbleChip(id: "isMultiGen",   label: "Multigenerational",    emoji: "👨‍👩‍👧‍👦", flag: .isMultiGenerational),
                BubbleChip(id: "householdHelp",label: "Household Help",       emoji: "🧹", flag: .hasHouseholdHelp),
                BubbleChip(id: "has529",       label: "529 College Fund",     emoji: "📈", flag: .has529),
                BubbleChip(id: "hasFSA",       label: "Dependent Care FSA",   emoji: "🏦", flag: .hasFSA),
                BubbleChip(id: "autoShipPet",  label: "Auto-Ship Pet Food",   emoji: "📦", flag: .usesAutoShipPetFood),
            ]),
            ChipSection(title: "Living Situation", chips: [
                BubbleChip(id: "hasRoommates", label: "Roommates",            emoji: "🏠", flag: .hasRoommates),
                BubbleChip(id: "workFromHome", label: "Work from Home",       emoji: "💻", flag: .workFromHome),
            ])
        ]
        
        // 3. Shopping
        chips["shopping"] = [
            ChipSection(title: "Groceries & Retail", chips: [
                BubbleChip(id: "usesAmazon",      label: "Amazon",        emoji: "📦", flag: .usesAmazon),
                BubbleChip(id: "usesTarget",      label: "Target",        emoji: "🎯", flag: .usesTarget),
                BubbleChip(id: "usesWalmart",     label: "Walmart",       emoji: "🛒", flag: .usesWalmart),
                BubbleChip(id: "usesCostco",      label: "Costco",        emoji: "🏬", flag: .usesCostco),
                BubbleChip(id: "usesSamsClub",    label: "Sam's Club",    emoji: "🏬", flag: .usesSamsClub),
                BubbleChip(id: "usesBJs",         label: "BJ's",          emoji: "🏬", flag: .usesBJs),
                BubbleChip(id: "publix",          label: "Publix",        emoji: "🛒", flag: .usesPublix),
                BubbleChip(id: "heb",             label: "H-E-B",         emoji: "🛒", flag: .usesHEB),
                BubbleChip(id: "meijer",          label: "Meijer",        emoji: "🛒", flag: .usesMeijer),
                BubbleChip(id: "wegmans",         label: "Wegmans",       emoji: "🛒", flag: .usesWegmans),
                BubbleChip(id: "kroger",          label: "Kroger / King Soopers", emoji: "🛒", flag: .usesKroger),
                BubbleChip(id: "safeway",         label: "Safeway / Vons", emoji: "🛒", flag: .usesSafeway),
                BubbleChip(id: "albertsons",      label: "Albertsons",    emoji: "🛒", flag: .usesAlbertsons),
            ].filter { isAvailable($0.id) }),
            
            ChipSection(title: "Food Delivery", chips: [
                BubbleChip(id: "usesDoorDash",    label: "DoorDash",      emoji: "🍕", flag: .usesDoorDash),
                BubbleChip(id: "usesUberEats",    label: "Uber Eats",     emoji: "🍔", flag: .usesUberEats),
                BubbleChip(id: "usesGrubhub",     label: "Grubhub",       emoji: "🌮", flag: .usesGrubhub),
                BubbleChip(id: "usesInstacart",   label: "Instacart",     emoji: "🛒", flag: .usesInstacart),
            ]),
            
            ChipSection(title: "Home & Specialty", chips: [
                BubbleChip(id: "usesREI",         label: "REI",           emoji: "🏕️", flag: .usesREI),
                BubbleChip(id: "usesBestBuy",     label: "Best Buy",      emoji: "🔵", flag: .usesBestBuy),
                BubbleChip(id: "usesIKEA",        label: "IKEA",          emoji: "🪑", flag: .usesIKEA),
                BubbleChip(id: "usesWayfair",     label: "Wayfair",       emoji: "🪴", flag: .usesWayfair),
                BubbleChip(id: "usesHelloFresh",  label: "HelloFresh",    emoji: "🥗", flag: .usesHelloFresh),
                BubbleChip(id: "usesBlueApron",   label: "Blue Apron",    emoji: "🍳", flag: .usesBlueApron),
                BubbleChip(id: "usesOtherKit",    label: "Other Meal Kit",emoji: "🧑‍🍳", flag: .usesOtherMealKit),
            ])
        ]
        
        // 4. Streaming
        chips["streaming"] = [
            ChipSection(title: "TV & Movies", chips: [
                BubbleChip(id: "netflix",     label: "Netflix",          emoji: "🎬", flag: .usesNetflix),
                BubbleChip(id: "hulu",        label: "Hulu",             emoji: "📺", flag: .usesHulu),
                BubbleChip(id: "disney",      label: "Disney+",          emoji: "✨", flag: .usesDisneyPlus),
                BubbleChip(id: "hbo",         label: "Max / HBO",        emoji: "🎭", flag: .usesHBOMax),
                BubbleChip(id: "appletv",     label: "Apple TV+",        emoji: "🍎", flag: .usesAppleTVPlus),
                BubbleChip(id: "paramount",   label: "Paramount+",       emoji: "⭐", flag: .usesParamountPlus),
                BubbleChip(id: "peacock",     label: "Peacock",          emoji: "🦚", flag: .usesPeacock),
            ]),
            ChipSection(title: "Audio & Gaming", chips: [
                BubbleChip(id: "spotify",     label: "Spotify",          emoji: "🎵", flag: .usesSpotify),
                BubbleChip(id: "applemusic",  label: "Apple Music",      emoji: "🎶", flag: .usesAppleMusic),
                BubbleChip(id: "siriusxm",    label: "SiriusXM",         emoji: "📻", flag: .usesSiriusXM),
                BubbleChip(id: "ytpremium",   label: "YouTube Premium",  emoji: "▶️", flag: .usesYouTubePremium),
                BubbleChip(id: "gaming",      label: "Gaming (Xbox/PS)", emoji: "🎮", flag: .usesGamingSubs),
            ]),
            ChipSection(title: "Internet & Cable", chips: [
                BubbleChip(id: "xfinity",     label: "Xfinity",          emoji: "📺", flag: .usesXfinity),
                BubbleChip(id: "spectrum",    label: "Spectrum",         emoji: "📺", flag: .usesSpectrum),
                BubbleChip(id: "directv",     label: "DirecTV",          emoji: "📡", flag: .usesDirecTV),
                BubbleChip(id: "dish",        label: "Dish Network",     emoji: "📡", flag: .usesDish),
                BubbleChip(id: "verizon",     label: "Verizon Fios",     emoji: "📺", flag: .usesVerizonFios),
                BubbleChip(id: "att",         label: "AT&T",             emoji: "🌐", flag: .usesATT),
                BubbleChip(id: "cox",         label: "Cox",              emoji: "📺", flag: .usesCox),
                BubbleChip(id: "optimum",     label: "Optimum",          emoji: "📺", flag: .usesOptimum),
            ].filter { isAvailable($0.id) })
        ]
        
        // 5. Fitness
        chips["fitness"] = [
            ChipSection(title: "Gym Memberships", chips: [
                BubbleChip(id: "planetfitness", label: "Planet Fitness", emoji: "💜", flag: .usesPlanetFitness),
                BubbleChip(id: "equinox",       label: "Equinox",        emoji: "⚫", flag: .usesEquinox),
                BubbleChip(id: "lafitness",     label: "LA Fitness",     emoji: "💙", flag: .usesLAFitness),
                BubbleChip(id: "ymca",          label: "YMCA",           emoji: "🏊", flag: .usesYMCA),
                BubbleChip(id: "24hourfitness", label: "24 Hour Fitness",emoji: "💪", flag: .uses24HourFitness),
                BubbleChip(id: "lifetime",      label: "Life Time",      emoji: "🏊", flag: .usesLifeTime),
                BubbleChip(id: "jcc",           label: "JCC",            emoji: "🏃", flag: .usesJCC),
                BubbleChip(id: "vasa",          label: "VASA Fitness",   emoji: "🏋️", flag: .usesVASA),
                BubbleChip(id: "eos",           label: "EoS Fitness",    emoji: "🏋️", flag: .usesEoS),
                BubbleChip(id: "chuze",         label: "Chuze Fitness",  emoji: "🧘", flag: .usesChuze),
                BubbleChip(id: "crunch",        label: "Crunch Fitness", emoji: "💪", flag: .usesCrunch),
                BubbleChip(id: "anytimefitness",label: "Anytime Fitness",emoji: "🏃", flag: .usesAnytimeFitness),
                BubbleChip(id: "localgym",      label: "Local Gym",      emoji: "🏃", flag: .hasGymMembership),
                BubbleChip(id: "nogym",         label: "No Gym",         emoji: "🚶", flag: nil),
            ].filter { isAvailable($0.id) }),
            ChipSection(title: "Classes & Home", chips: [
                BubbleChip(id: "peloton",       label: "Peloton",        emoji: "🚴", flag: .usesPeloton),
                BubbleChip(id: "classpass",     label: "ClassPass",      emoji: "🧘", flag: .usesClassPass),
                BubbleChip(id: "crossfit",      label: "CrossFit",       emoji: "🏋️", flag: .usesCrossFit),
                BubbleChip(id: "orangetheory",  label: "Orangetheory",   emoji: "🔥", flag: .usesOrangeTheory),
            ])
        ]
        
        // 6. More
        chips["more"] = [
            ChipSection(title: "Real Estate & Insurance", chips: [
                BubbleChip(id: "hasMortgage",    label: "Mortgage",           emoji: "🏡", flag: .hasMortgage),
                BubbleChip(id: "isOwning",       label: "Own My Home",        emoji: "🔑", flag: .isOwning),
                BubbleChip(id: "hasHOA",         label: "HOA",                emoji: "🏘️", flag: .hasHOA),
                BubbleChip(id: "hasHomeSecurity",label: "Home Security",      emoji: "🔒", flag: .hasHomeSecurity),
                BubbleChip(id: "hasLifeIns",     label: "Life Insurance",     emoji: "🛡️", flag: .hasLifeInsurance),
            ]),
            ChipSection(title: "Professional & Financial", chips: [
                BubbleChip(id: "isSelfEmployed", label: "Self-Employed",      emoji: "💼", flag: .isSelfEmployed),
                BubbleChip(id: "runsBusiness",   label: "Runs Business",      emoji: "🏢", flag: .runsBusiness),
                BubbleChip(id: "cloudInfra",     label: "Cloud Infra (AWS)",  emoji: "☁️", flag: .usesCloudInfrastructure),
                BubbleChip(id: "crypto",         label: "Crypto Exchange",    emoji: "🪙", flag: .holdsCrypto),
                BubbleChip(id: "hasProfLicense", label: "Pro Licenses",       emoji: "📋", flag: .hasProfessionalLicenses),
                BubbleChip(id: "hasStudentLoans",label: "Student Loans",      emoji: "🎓", flag: .hasStudentLoans),
                BubbleChip(id: "hasInvestments", label: "Investments",        emoji: "📈", flag: .hasInvestmentAccounts),
            ]),
            ChipSection(title: "Life & Retirement", chips: [
                BubbleChip(id: "isVeteran",      label: "Veteran / Military", emoji: "🎖️", flag: .isVeteran),
                BubbleChip(id: "hasMedicare",    label: "Medicare",           emoji: "⚕️", flag: .hasMedicare),
                BubbleChip(id: "isRetired",      label: "Retired",            emoji: "🌅", flag: .isRetired),
                BubbleChip(id: "hasPension",     label: "Pension Provider",   emoji: "🏦", flag: .hasPension),
                BubbleChip(id: "mailPharmacy",   label: "Mail-Order Rx",      emoji: "📦", flag: .usesMailOrderPharmacy),
                BubbleChip(id: "hasWill",        label: "Will / Estate",      emoji: "📜", flag: .hasWill),
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
        // Initialize vm with the move's origin zip code to drive regional intelligence
        self._vm = State(initialValue: LifestyleViewModel(originZip: move.originZip))
    }

    private let screenKeys = ["transport", "household", "shopping", "streaming", "fitness", "more"]
    private let screenTitles = [
        ("🚗", "How do you get around?",          "Tap everything that applies — you can always edit later."),
        ("🏠", "Who's in your household?",         "This helps us find the right tasks for your family."),
        ("🛍️", "Where do you shop & order?",       "We'll make sure each service knows your new address."),
        ("📺", "What do you watch & listen to?",   "Billing addresses matter — we'll add them to your list."),
        ("💪", "What keeps you active?",            "Memberships need updating so charges go to the right place."),
        ("🌟", "Anything else in your life?",       "These unlock important tasks you don't want to miss."),
        ("🏦", "Your banks & financial accounts",   "Pick your institutions — we'll build a task for each one."),
    ]

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            Group {
                if vm.currentScreen < 6 {
                    let key = screenKeys[vm.currentScreen]
                    let (emoji, title, subtitle) = screenTitles[vm.currentScreen]
                    InterviewScreenView(
                        emoji: emoji, title: title, subtitle: subtitle,
                        stepIndex: vm.currentScreen, totalSteps: vm.totalScreens,
                        onBack: { vm.back() },
                        onNext:  { vm.next() }
                    ) {
                        BubblePickerView(
                            sections: vm.chips[key] ?? [],
                            onToggle: { chip in vm.toggle(chip: chip, in: key) }
                        )
                    }
                } else {
                    // Screen 7 — Financial institutions
                    FinancialScreenView(
                        selectedInstitutions: Binding(
                            get: { vm.selectedInstitutions },
                            set: { vm.selectedInstitutions = $0 }
                        ),
                        stepIndex: 6, totalSteps: vm.totalScreens,
                        onBack: { vm.back() },
                        onFinish: { commitAndComplete() }
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.3), value: vm.currentScreen)
        }
    }

    // MARK: - Commit

    private func commitAndComplete() {
        // 1. Save lifestyle profile
        let profile = LifestyleProfile()
        profile.move = move
        profile.activeFlags = vm.allActiveFlags

        modelContext.insert(profile)
        move.lifestyleProfile = profile

        // 2. Save institutions
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

        // 3. Generate tasks
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: institutions)
        for task in tasks {
            task.move = move
            modelContext.insert(task)
        }
        move.tasks = tasks

        withAnimation(.easeInOut(duration: 0.4)) { onComplete() }
    }
}
