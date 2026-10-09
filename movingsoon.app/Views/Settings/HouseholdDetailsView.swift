import SwiftUI
import SwiftData

struct HouseholdQuestions: View {
    @Bindable var vm: LifestyleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            answer("Children at home?", selection: $vm.childrenAnswer)
            if vm.hasKids {
                Stepper("Children: \(vm.childCount)", value: $vm.childCount, in: 1...8)
            }
            answer("Pets?", selection: $vm.petsAnswer)
            if vm.hasPets {
                ForEach(PetSpecies.allCases, id: \.self) { species in
                    Toggle(species.displayLabel, isOn: Binding(
                        get: { vm.petSpecies.contains(species) },
                        set: { if $0 { vm.petSpecies.insert(species) } else { vm.petSpecies.remove(species) } }
                    ))
                }
            }
            Picker("Previous home", selection: $vm.originHousing) {
                ForEach(HousingArrangement.allCases) { Text($0.title).tag($0) }
            }
            Picker("New home", selection: $vm.destinationHousing) {
                ForEach(HousingArrangement.allCases) { Text($0.title).tag($0) }
            }
            DisclosureGroup("A few more details (optional)") {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("New home type", selection: $vm.homeKind) {
                        ForEach(HomeKind.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(vm.householdSize == 0 ? "Household size: not set" : "People moving: \(vm.householdSize)",
                            value: $vm.householdSize, in: 0...20)
                    Text("Include adults and children. Leave at zero to skip.")
                        .font(.caption).foregroundStyle(.secondary)
                    answer("Do you manage utility accounts?", selection: $vm.utilitiesAnswer)
                }.padding(.top, 12)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.accentPrimary)
    }

    private func answer(_ title: String, selection: Binding<HouseholdAnswer>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.medium))
            Picker(title, selection: selection) {
                ForEach(HouseholdAnswer.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
        }
    }
}

struct HouseholdDetailsView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: LifestyleViewModel

    init(move: Move) {
        self.move = move
        let vm = LifestyleViewModel(initialFlags: move.lifestyleProfile?.activeFlags ?? [],
                                    initialChildCount: move.lifestyleProfile?.childCount)
        if let profile = move.lifestyleProfile { vm.loadHousehold(from: profile) }
        _vm = State(initialValue: vm)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("These answers help us suggest overlooked accounts. Skip anything you don't want to answer.")
                        .foregroundStyle(Theme.textSecondary)
                    HouseholdQuestions(vm: vm)
                    Text("Your completed tasks and service choices are kept. You can remove any open task that no longer applies.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }.padding(24)
            }
            .background(Theme.backgroundPrimary)
            .navigationTitle("Your household")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let profile = move.lifestyleProfile else { return }
                        vm.saveHousehold(to: profile)
                        MoveChecklistService.addRelevantTasks(for: move, in: modelContext)
                        dismiss()
                    }
                }
            }
        }
    }
}
