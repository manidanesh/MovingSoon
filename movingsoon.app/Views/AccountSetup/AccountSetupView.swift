// AccountSetupView.swift — "Which banks do you have?" personalization screen
import SwiftUI
import SwiftData

struct AccountSetupView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    let onComplete: () -> Void

    @State private var selected: Set<KnownInstitution> = []
    @State private var searchText = ""
    @State private var activeSection: InstitutionType = .bank

    private let sections: [(InstitutionType, [KnownInstitution])] = [
        (.bank,        KnownInstitutions.banks),
        (.creditUnion, KnownInstitutions.creditUnions),
        (.creditCard,  KnownInstitutions.creditCards),
        (.investment,  KnownInstitutions.investments),
        (.studentLoan, KnownInstitutions.studentLoans),
        (.mortgage,    KnownInstitutions.mortgages),
    ]

    private var filteredSections: [(InstitutionType, [KnownInstitution])] {
        if searchText.isEmpty { return sections }
        return sections.compactMap { (type, list) in
            let filtered = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            return filtered.isEmpty ? nil : (type, filtered)
        }
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("🏦")
                        .font(.system(size: 40))
                        .padding(.top, 24)

                    Text("Which accounts are you moving?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    Text("We'll create a task for each one — no guessing.")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textSecondary)

                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.textTertiary)
                        TextField("Search banks, cards, brokerages…", text: $searchText)
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                // MARK: Section tabs
                if searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sections, id: \.0) { (type, _) in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { activeSection = type }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 12))
                                        Text(type.rawValue)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(activeSection == type ? .white : Theme.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        activeSection == type ? Theme.accentPrimary : Theme.backgroundCard,
                                        in: Capsule()
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }
                }

                // MARK: Institution grid
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        ForEach(displayedSections, id: \.0) { (type, institutions) in
                            VStack(alignment: .leading, spacing: 10) {
                                if searchText.isEmpty || filteredSections.count > 1 {
                                    Label(type.rawValue, systemImage: type.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Theme.textTertiary)
                                        .padding(.horizontal, 24)
                                }

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 10) {
                                    ForEach(institutions) { institution in
                                        InstitutionSelectCard(
                                            institution: institution,
                                            isSelected: selected.contains(institution)
                                        ) {
                                            withAnimation(.spring(duration: 0.25)) {
                                                if selected.contains(institution) {
                                                    selected.remove(institution)
                                                } else {
                                                    selected.insert(institution)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 120)
                }

                Spacer(minLength: 0)
            }

            // MARK: Sticky bottom bar
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    Divider().background(Theme.backgroundElevated)
                    HStack(spacing: 12) {
                        if !selected.isEmpty {
                            Text("\(selected.count) selected")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.accentPrimary)
                        }
                        Spacer()
                        Button(selected.isEmpty ? "Skip for now" : "Build My Checklist →") {
                            commitInstitutions()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(selected.isEmpty ? Theme.backgroundElevated : Theme.accentPrimary,
                                    in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Theme.backgroundPrimary)
                }
            }
        }
    }

    // MARK: - Helpers

    private var displayedSections: [(InstitutionType, [KnownInstitution])] {
        if !searchText.isEmpty { return filteredSections }
        return sections.filter { $0.0 == activeSection }
    }

    private func commitInstitutions() {
        // Save selected institutions to SwiftData
        for known in selected {
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
        }

        // Generate institution-specific tasks and add them to the move
        if !selected.isEmpty {
            // Remove generic financial tasks first
            let genericFinancialTitles = [
                "Update Primary Bank Account",
                "Update All Credit Cards",
                "Update Investment Accounts (401k, Brokerage)",
                "Update Bank / Checking Account",
                "Update Credit Cards"
            ]
            move.tasks.removeAll { genericFinancialTitles.contains($0.title) }

            // Add per-institution tasks
            let institutionTasks = TaskListProvider.institutionTasks(for: Array(selected))
            for task in institutionTasks {
                task.move = move
                modelContext.insert(task)
                move.tasks.append(task)
            }
        }

        onComplete()
    }
}

// MARK: - Institution Selection Card

private struct InstitutionSelectCard: View {
    let institution: KnownInstitution
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                InstitutionBadgeView(initials: institution.initials, colorHex: institution.colorHex, size: 32)
                Text(institution.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Theme.accentPrimary : Theme.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isSelected ? Theme.accentPrimary : Theme.backgroundElevated,
                                lineWidth: 1.5
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
