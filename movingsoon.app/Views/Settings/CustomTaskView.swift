import SwiftUI
import SwiftData

struct CustomTaskView: View {
    let move: Move
    let task: ChecklistTask?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var category: TaskCategory
    @State private var note: String
    @State private var dueDate: Date
    @State private var errorMessage: String?
    @State private var saving = false

    init(move: Move, task: ChecklistTask? = nil) {
        self.move = move
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _category = State(initialValue: task?.category ?? .utilities)
        _note = State(initialValue: task?.customerNote ?? "")
        _dueDate = State(initialValue: task?.baseDueDate(moveDate: move.effectiveAnchorDate)
            ?? max(Calendar.current.startOfDay(for: Date()), move.effectiveAnchorDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who needs your new address?") {
                    TextField("Service or organization", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) }
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
                    if task?.status == .completed {
                        Text("This item stays complete. Reopen it from All tasks if you need reminders again.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(Theme.priorityCritical) } }
            }
            .navigationTitle(task == nil ? "Add your own item" : "Edit your item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(task == nil ? "Add" : "Save", action: save)
                        .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        do {
            try CustomTaskService.save(title: title, category: category, dueDate: dueDate, note: note,
                                       task: task, move: move, context: modelContext)
            SmartReminderService.shared.reschedule(for: move)
            LocationManager.shared.attach(move, context: modelContext)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
