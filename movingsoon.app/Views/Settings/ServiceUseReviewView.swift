import SwiftUI
import SwiftData

struct ServiceUseReviewView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var expanded: Set<String> = []
    @State private var managingAccounts: CatalogItem?

    private var items: [CatalogItem] {
        let pilotIDs = Set(ServiceEvidenceCatalog.bundled.services.map(\.id))
        return ChecklistGenerator.catalogForReview(for: move)
            .filter { $0.topic.isRecurringReview || pilotIDs.contains($0.canonicalID) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Text("The routines that move with you").font(.title2.weight(.bold))
                    Text("Think about what arrives at your door, places you belong to and people who visit your home. Open any section that sounds familiar; every question is optional.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    Text("Your answers stay on this device. Add a checklist reminder separately when you need one.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                    TextField("Search groceries, wine, clothing, pets…", text: $search)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(14).background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Search recurring accounts")
                    let sections = CatalogBrowseSection.sections(for: items.filter { $0.matchesSearch(search) })
                    ForEach(sections) { section in
                        DisclosureGroup(isExpanded: Binding(
                            get: { !search.isEmpty || expanded.contains(section.id) },
                            set: { if $0 { expanded.insert(section.id) } else { expanded.remove(section.id) } }
                        )) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(section.topic.prompt).font(.subheadline).foregroundStyle(Theme.textSecondary)
                                ForEach(section.items) { item in question(item) }
                            }.padding(.top, 14)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title).font(.headline)
                                Text("\(section.family.title) · \(section.items.filter { move.serviceUseResponses[$0.canonicalID] != nil }.count) of \(section.items.count) answered")
                                    .font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .padding(16).background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 16))
                    }
                    if sections.isEmpty {
                        Text("No recurring account matched. The full Review services catalog also lets you add your own item.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                }.padding(20)
            }
            .background(Theme.backgroundPrimary).foregroundStyle(Theme.textPrimary)
            .navigationTitle("Recurring accounts").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $managingAccounts) { ServiceAccountsView(move: move, item: $0) }
        }
    }

    private func question(_ item: CatalogItem) -> some View {
        let id = item.canonicalID
        let answer = move.serviceUseResponses[id]?.answer
        let onList = MoveChecklistService.contains(item, in: move)
        let pilotQuestion = ServiceEvidenceCatalog.bundled.services.first { $0.id == id }?.question
        return VStack(alignment: .leading, spacing: 12) {
            Text("\(item.emoji) \(item.title)").font(.subheadline.weight(.semibold))
            Text(pilotQuestion ?? "Do you currently use this account or service?")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { answers(id, current: answer) }
                VStack(alignment: .leading, spacing: 12) { answers(id, current: answer) }
            }.font(.subheadline)
            if answer == .usesService && !onList {
                Button("Add a reminder to my checklist") {
                    MoveChecklistService.confirm(item, for: move, in: modelContext)
                }.font(.subheadline.weight(.semibold))
            }
            if onList {
                Button("Manage accounts & dates (\(MoveChecklistService.accounts(for: item, in: move).count))") {
                    managingAccounts = item
                }.font(.caption.weight(.semibold))
            }
            if answer != nil {
                Button("Clear answer") {
                    move.recordServiceUse(nil, for: id)
                    modelContext.saveOrLog()
                }.font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Divider()
        }
    }

    @ViewBuilder private func answers(_ id: String, current: ServiceUseAnswer?) -> some View {
        answerButton("I use this", .usesService, id: id, current: current)
        answerButton("I don’t use this", .doesNotUse, id: id, current: current)
        answerButton("Not sure", .unsure, id: id, current: current)
    }

    private func answerButton(_ title: String, _ answer: ServiceUseAnswer,
                              id: String, current: ServiceUseAnswer?) -> some View {
        Button {
            move.recordServiceUse(answer, for: id)
            modelContext.saveOrLog()
        } label: {
            Text(current == answer ? "✓ \(title)" : title)
                .foregroundStyle(current == answer ? Theme.accentPrimary : Theme.textSecondary)
        }.accessibilityAddTraits(current == answer ? .isSelected : [])
    }
}
