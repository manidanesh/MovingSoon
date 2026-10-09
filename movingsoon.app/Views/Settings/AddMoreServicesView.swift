import SwiftUI
import SwiftData
import CoreLocation

struct AddMoreServicesView: View {
    let move: Move
    var area: AreaMarketComparison? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var expanded: Set<ReviewFamily> = []
    @State private var expandedTopics: Set<String> = []
    @State private var selectedTopic: CatalogTopic?
    @State private var managingAccounts: CatalogItem?
    @State private var showingCustom = false
    @State private var showingHousehold = false
    @State private var showingBanks = false
    @State private var showingServiceUse = false
    @State private var providerChecks: [String: ProviderAvailabilityResult] = [:]
    @State private var checkingProviders: Set<String> = []

    private var catalog: [CatalogItem] {
        ChecklistGenerator.catalogForReview(for: move)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    private var filtered: [CatalogItem] {
        catalog.filter { (selectedTopic == nil || $0.topic == selectedTopic) && $0.matchesSearch(search) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Text("A quick check for anything you missed")
                        .font(.title2.weight(.bold)).foregroundStyle(Theme.textPrimary)
                    Text("Add services you use, skip those you don't, and mark each category reviewed when you're ready.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    TextField("Try wine, Stitch Fix, groceries or autoship", text: $search)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(14).background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Search all services")
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 18) { shortcuts }
                        VStack(alignment: .leading, spacing: 14) { shortcuts }
                    }
                    Button("Review recurring accounts") { showingServiceUse = true }
                        .font(.subheadline.weight(.semibold))
                    topicShortcuts
                    if search.isEmpty && selectedTopic == nil {
                        ForEach(ServiceDiscoveryEngine.spotlight(for: move, area: area)) { suggestion in
                            ServiceSuggestionRow(suggestion: suggestion, onAdd: { add(suggestion.item) },
                                onResponse: { respond(suggestion.item, $0) })
                        }
                    }
                    Text("\(move.reviewedFamilies.count) of \(ReviewFamily.allCases.count) categories reviewed")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    ForEach(ReviewFamily.allCases) { family in
                        let items = filtered.filter { $0.reviewFamily == family }
                        if !items.isEmpty {
                            DisclosureGroup(isExpanded: Binding(
                                get: { !search.isEmpty || selectedTopic != nil || expanded.contains(family) },
                                set: { if $0 { expanded.insert(family) } else { expanded.remove(family) } }
                            )) {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(CatalogBrowseSection.sections(for: items)) { section in
                                        topicSection(section)
                                    }
                                    if search.isEmpty && selectedTopic == nil {
                                        Button(move.reviewedFamilies.contains(family) ? "Reviewed — review again" : "I've reviewed this category") {
                                            var reviewed = move.reviewedFamilies
                                            if reviewed.contains(family) { reviewed.remove(family) }
                                            else { reviewed.insert(family); expanded.remove(family) }
                                            move.reviewedFamilies = reviewed
                                            modelContext.saveOrLog()
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        Text("Marking a category reviewed keeps each service answer unchanged.")
                                            .font(.caption).foregroundStyle(Theme.textTertiary)
                                    }
                                }.padding(.top, 14)
                            } label: {
                                HStack {
                                    Text("\(family.emoji) \(family.title)")
                                    Spacer()
                                    if move.reviewedFamilies.contains(family) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accentSuccess)
                                    }
                                }.foregroundStyle(Theme.textPrimary)
                            }
                            .padding(14).background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    if filtered.isEmpty {
                        Text("No matching service. Add your own item so it stays on your list.")
                            .foregroundStyle(Theme.textSecondary)
                        Button("Add your own item") { showingCustom = true }
                    }
                    if search.isEmpty && selectedTopic == nil { providerDiscovery }
                }.padding(20)
            }
            .background(Theme.backgroundPrimary)
            .navigationTitle("Review services")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showingCustom) { CustomTaskView(move: move) }
            .sheet(isPresented: $showingHousehold) { HouseholdDetailsView(move: move) }
            .sheet(isPresented: $showingBanks) { AddFinancialAccountsView(move: move) }
            .sheet(isPresented: $showingServiceUse) { ServiceUseReviewView(move: move) }
            .sheet(item: $managingAccounts) { ServiceAccountsView(move: move, item: $0) }
        }
    }

    @ViewBuilder private var shortcuts: some View {
        Button("Add your own item") { showingCustom = true }
        Button("Banks & cards") { showingBanks = true }
        Button("Your household") { showingHousehold = true }
    }

    private var topicShortcuts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Think through your everyday routines").font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), alignment: .leading)], alignment: .leading, spacing: 10) {
                ForEach([CatalogTopic.groceries, .wine, .clothing, .meals, .refills, .community]) { topic in
                    if catalog.contains(where: { $0.topic == topic }) {
                        Button {
                            selectedTopic = selectedTopic == topic ? nil : topic
                            search = ""
                        } label: {
                            Text(topic.title).font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                .background(selectedTopic == topic ? Theme.accentPrimary.opacity(0.2) : Theme.backgroundElevated,
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                        .accessibilityAddTraits(selectedTopic == topic ? .isSelected : [])
                    }
                }
            }
            if selectedTopic != nil {
                Button("Show all services") { selectedTopic = nil; search = "" }.font(.caption.weight(.semibold))
            }
        }
        .onChange(of: search) { _, value in
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { selectedTopic = nil }
        }
    }

    @ViewBuilder private func topicSection(_ section: CatalogBrowseSection) -> some View {
        if section.topic == .general {
            ForEach(section.items) { item in catalogRow(item) }
        } else {
            DisclosureGroup(isExpanded: Binding(
                get: { !search.isEmpty || selectedTopic != nil || expandedTopics.contains(section.id) },
                set: { if $0 { expandedTopics.insert(section.id) } else { expandedTopics.remove(section.id) } }
            )) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.topic.prompt).font(.caption).foregroundStyle(Theme.textSecondary)
                    ForEach(section.items) { item in catalogRow(item) }
                }.padding(.top, 10)
            } label: {
                Text("\(section.title) · \(section.items.count)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private func catalogRow(_ item: CatalogItem) -> some View {
        let onList = MoveChecklistService.contains(item, in: move)
        let response = move.serviceResponses[item.canonicalID]?.decision
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Text(item.emoji)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
                    Text(item.moveAction.title).font(.caption).foregroundStyle(Theme.textSecondary)
                    if !onList, let response {
                        Text(response == .notApplicable ? "You marked this as not applicable" : "Saved for another look")
                            .font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer(minLength: 4)
                if onList {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accentSuccess)
                        .accessibilityLabel("Already on your list")
                } else {
                    Button("Add") { add(item) }.font(.subheadline.weight(.semibold))
                        .accessibilityLabel("Add \(item.title)")
                }
            }
            if onList {
                Button("Accounts & dates (\(MoveChecklistService.accounts(for: item, in: move).count))") {
                    managingAccounts = item
                }.font(.caption.weight(.semibold))
            } else {
                HStack(spacing: 16) {
                    Button("Doesn't apply") { respond(item, .notApplicable) }
                    Button("Not sure") { respond(item, .unsure) }
                }.font(.caption).foregroundStyle(Theme.textSecondary)
            }
            if let guidance = item.moveGuidance {
                DisclosureGroup("What to check for your move") {
                    Text(guidance).font(.caption).foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                }.font(.caption)
            }
            Divider().overlay(Theme.backgroundElevated)
        }
    }

    private func add(_ item: CatalogItem) {
        MoveChecklistService.confirm(item, for: move, in: modelContext)
    }

    private func respond(_ item: CatalogItem, _ decision: ServiceDecision) {
        move.respond(to: item.canonicalID, with: decision)
        modelContext.saveOrLog()
    }

    private var providerDiscovery: some View {
        let items = catalog.filter { $0.poiCategory != nil && MoveChecklistService.contains($0, in: move)
            && (!$0.requires.isEmpty || !$0.requiresAny.isEmpty || $0.requiresConfirmation) }
        return Group {
            if !items.isEmpty {
                DisclosureGroup("Check nearby provider locations") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("When you tap Check, Apple receives the provider query and destination area. Map listings are leads to verify with the provider, including membership transfer or coverage.")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(item.title).font(.subheadline)
                                    Spacer()
                                    if checkingProviders.contains(item.id) { ProgressView() }
                                    else { Button(providerChecks[item.id] == nil ? "Check" : "Refresh") { checkProvider(item) } }
                                }
                                if let result = providerChecks[item.id] {
                                    Text(result.failed ? "Couldn't check listings. Try again later."
                                        : result.nearbyCount == 0 ? "No listings found. Availability is still unconfirmed."
                                        : "Apple Maps lists \(result.nearbyCount) nearby result(s)\(result.nearestName.map { ", including \($0)" } ?? ""). Verify with the provider.")
                                        .font(.caption).foregroundStyle(Theme.textSecondary)
                                    Text("Checked \(result.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2).foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                    }.padding(.top, 14)
                }.padding(14).background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @MainActor private func checkProvider(_ item: CatalogItem) {
        checkingProviders.insert(item.id)
        Task {
            defer { checkingProviders.remove(item.id) }
            var center = move.destinationCoordinate
            if center == nil {
                let places = try? await CLGeocoder().geocodeAddressString(move.destinationZip)
                center = places?.first?.location?.coordinate
            }
            guard let center else {
                providerChecks[item.id] = ProviderAvailabilityResult(nearbyCount: 0, nearestName: nil, checkedAt: Date(), failed: true)
                return
            }
            let query = item.title.components(separatedBy: " — ").first ?? item.title
            providerChecks[item.id] = await ProviderAvailabilityService.check(provider: query, near: center)
        }
    }
}

private struct AddFinancialAccountsView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<KnownInstitution> = []

    var body: some View {
        NavigationStack {
            InstitutionPickerGrid(selectedInstitutions: $selected, stateBucket: move.originStateBucket ?? move.destinationStateBucket)
                .background(Theme.backgroundPrimary)
                .navigationTitle("Banks & cards")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add selected") {
                            for known in selected {
                                let existing = move.institutions.first { $0.name == known.name && $0.institutionType == known.type }
                                let institution = existing ?? FinancialInstitution(name: known.name, initials: known.initials,
                                    colorHex: known.colorHex, type: known.type, websiteURL: known.websiteURL)
                                if existing == nil {
                                    institution.move = move
                                    modelContext.insert(institution)
                                    move.institutions.append(institution)
                                }
                                let key = "institution:\(known.type.rawValue):\(known.name)"
                                move.respond(to: key, with: .confirmed)
                                if move.tasks.contains(where: { $0.catalogItemID == key || ($0.catalogItemID == nil && $0.institutionName == known.name) }) { continue }
                                let task = ChecklistGenerator.task(from: institution)
                                task.catalogItemID = key
                                task.move = move
                                modelContext.insert(task)
                                move.tasks.append(task)
                                move.completionCelebratedAt = nil
                            }
                            modelContext.saveOrLog()
                            dismiss()
                        }.disabled(selected.isEmpty)
                    }
                }
        }
    }
}
