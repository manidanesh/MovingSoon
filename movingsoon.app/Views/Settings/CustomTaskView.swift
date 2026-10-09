import SwiftUI
import SwiftData

struct CustomTaskView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var family: ReviewFamily = .home
    @State private var note = ""
    @State private var dueDate: Date

    init(move: Move) {
        self.move = move
        _dueDate = State(initialValue: max(Date(), move.anchorDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who needs your new address?") {
                    TextField("Service or organization", text: $title)
                    Picker("Category", selection: $family) {
                        ForEach(ReviewFamily.allCases) { Text($0.title).tag($0) }
                    }
                    DatePicker("Remind me by", selection: $dueDate, displayedComponents: .date)
                }
                Section("Anything to remember?") {
                    TextField("Optional note or confirmation reference", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Text("Your item and note are saved on this device.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add your own item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if MoveChecklistService.addCustom(title: String(title.prefix(160)), family: family,
                            dueDate: dueDate, note: String(note.prefix(1000)), to: move, in: modelContext) != nil {
                            dismiss()
                        }
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
