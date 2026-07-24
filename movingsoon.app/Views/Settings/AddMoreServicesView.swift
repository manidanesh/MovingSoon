// AddMoreServicesView.swift — Append tasks for services missed during onboarding
// Never removes existing tasks or resets progress. (#8)
import SwiftUI
import SwiftData

struct AddMoreServicesView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm: LifestyleViewModel

    init(move: Move) {
        self.move = move
        self._vm = State(initialValue: LifestyleViewModel())
    }

    // Count of new tasks that will be added (not already in the list)
    private var newTaskCount: Int {
        let existingTitles = Set(move.tasks.map { $0.title })
        let flags = vm.allActiveFlags
        let catalogCount = ChecklistGenerator.matchingItems(flags: flags)
            .filter { !existingTitles.contains($0.title) }
            .count
        let institutionCount = vm.selectedInstitutions.filter { inst in
            !existingTitles.contains(inst.name)
        }.count
        return catalogCount + institutionCount
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // Header info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What did you miss?")
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(Theme.textPrimary)
                            Text("Select anything you want to add. Your existing tasks and progress won't be affected.")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(3)
                        }

                        // Financial institutions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Financial Accounts")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(1.5)

                            InstitutionPickerGrid(
                                selectedInstitutions: Binding(
                                    get: { vm.selectedInstitutions },
                                    set: { vm.selectedInstitutions = $0 }
                                ),
                                stateBucket: move.originStateBucket ?? move.destinationStateBucket
                            )
                        }

                        // Optional extras
                        let categories: [(id: String, label: String, emoji: String)] = [
                            ("shopping",  "Shopping & Delivery",  "📦"),
                            ("streaming", "Streaming & Cable",    "📺"),
                            ("fitness",   "Fitness & Wellness",   "💪"),
                            ("transport", "Vehicles & Travel",    "🚗"),
                            ("life",      "Life & Finance",       "💼"),
                        ]

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

                        // Add button
                        Button(action: applyAndDismiss) {
                            HStack(spacing: 8) {
                                if newTaskCount > 0 {
                                    Text("Add \(newTaskCount) tasks")
                                        .font(.system(size: 17, weight: .bold))
                                } else {
                                    Text("Nothing new selected")
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .foregroundColor(newTaskCount > 0 ? .black : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                newTaskCount > 0 ? Theme.accentPrimary : Theme.backgroundElevated,
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .animation(.easeInOut(duration: 0.2), value: newTaskCount)
                        }
                        .buttonStyle(.plain)
                        .disabled(newTaskCount == 0)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: newTaskCount)

                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Add Services")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Apply new tasks without touching existing ones

    private func applyAndDismiss() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let existingTitles = Set(move.tasks.map { $0.title })
        let profile = move.lifestyleProfile ?? LifestyleProfile()
        let flags = vm.allActiveFlags.union(profile.activeFlags)

        // Update the profile with newly selected flags (additive)
        if let lp = move.lifestyleProfile {
            lp.activeFlags = flags
        }

        // Generate new catalog tasks
        for item in ChecklistGenerator.matchingItems(flags: flags) {
            guard !existingTitles.contains(item.title) else { continue }
            let task = ChecklistTask(
                title: item.title,
                category: item.category,
                priority: item.priority,
                tMinusDays: item.tMinusDays,
                isHeroItem: false,
                deepLinkURL: item.deepLinkURL
            )
            task.institutionColorHex = item.brandColorHex
            task.institutionInitials = item.emoji
            task.poiCategory = item.poiCategory
            task.move = move
            modelContext.insert(task)
            move.tasks.append(task)
        }

        // Add new institution tasks
        for known in vm.selectedInstitutions {
            guard !existingTitles.contains(known.name) else { continue }
            let fi = FinancialInstitution(
                name: known.name,
                initials: known.initials,
                colorHex: known.colorHex,
                type: known.type,
                websiteURL: known.websiteURL
            )
            fi.move = move
            modelContext.insert(fi)
            move.institutions.append(fi)

            let task = ChecklistTask(
                title: known.name,
                category: .financial,
                priority: known.type == .bank || known.type == .creditUnion ? .critical : .high,
                tMinusDays: known.type == .bank || known.type == .creditUnion ? -14 : -7
            )
            task.institutionName = known.name
            task.institutionInitials = known.initials
            task.institutionColorHex = known.colorHex
            task.deepLinkURLString = known.websiteURL?.absoluteString
            task.move = move
            if known.type == .bank || known.type == .creditUnion {
                task.poiCategory = .bank
            }
            modelContext.insert(task)
            move.tasks.append(task)
        }

        try? modelContext.save()
        dismiss()
    }
}
