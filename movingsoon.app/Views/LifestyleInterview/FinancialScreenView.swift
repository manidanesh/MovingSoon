// FinancialScreenView.swift — Screen 7 of lifestyle interview: bank & card picker
import SwiftUI

struct FinancialScreenView: View {
    @Binding var selectedInstitutions: Set<KnownInstitution>
    let stepIndex: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onFinish: () -> Void

    @State private var searchText = ""
    @State private var activeType: InstitutionType = .bank

    private let sections: [(InstitutionType, [KnownInstitution])] = [
        (.bank,        KnownInstitutions.banks),
        (.creditUnion, KnownInstitutions.creditUnions),
        (.creditCard,  KnownInstitutions.creditCards),
        (.investment,  KnownInstitutions.investments),
        (.studentLoan, KnownInstitutions.studentLoans),
        (.mortgage,    KnownInstitutions.mortgages),
    ]

    var body: some View {
        InterviewScreenView(
            emoji: "🏦",
            title: "Your banks & accounts",
            subtitle: "We'll create a dedicated task for each one — no generic lists.",
            stepIndex: stepIndex,
            totalSteps: totalSteps,
            onBack: onBack,
            onNext: onFinish
        ) {
            VStack(spacing: 16) {
                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(Theme.textTertiary)
                    TextField("Search banks, cards…", text: $searchText)
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                // Type tabs
                if searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sections, id: \.0) { (type, _) in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { activeType = type }
                                } label: {
                                    Text(type.rawValue)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(activeType == type ? .white : Theme.textSecondary)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(activeType == type ? Theme.accentPrimary : Theme.backgroundCard,
                                                    in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Grid
                let display = displayedInstitutions
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(display) { institution in
                        let isSelected = selectedInstitutions.contains(institution)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if isSelected { selectedInstitutions.remove(institution) }
                                else { selectedInstitutions.insert(institution) }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                InstitutionBadgeView(initials: institution.initials,
                                                     colorHex: institution.colorHex, size: 30)
                                Text(institution.name)
                                    .font(.system(size: 13, weight: .medium, design: .default))
                                    .foregroundColor(isSelected ? .white : Theme.textSecondary)
                                    .lineLimit(2).minimumScaleFactor(0.8)
                                Spacer(minLength: 0)
                                if isSelected {
                                    Circle()
                                        .fill(Theme.accentPrimary)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isSelected ? Theme.accentPrimary.opacity(0.1) : Color.clear)
                                    .overlay(RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(isSelected ? Theme.accentPrimary.opacity(0.6) : Theme.hairline,
                                                      lineWidth: isSelected ? 1 : 0.5))
                            )
                        }
                        .scaleEffect(isSelected ? 0.98 : 1.0)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                if !selectedInstitutions.isEmpty {
                    Text("\(selectedInstitutions.count) account\(selectedInstitutions.count == 1 ? "" : "s") selected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.accentPrimary)
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    private var displayedInstitutions: [KnownInstitution] {
        if !searchText.isEmpty {
            return KnownInstitutions.all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return sections.first(where: { $0.0 == activeType })?.1 ?? []
    }
}
