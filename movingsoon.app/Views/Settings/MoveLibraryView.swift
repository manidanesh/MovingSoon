import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct MoveLibraryView: View {
    @Query(sort: \Move.createdAt, order: .reverse) private var moves: [Move]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMove: Move?
    @State private var exportDocument = ChecklistFile()
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingBackup: MoveBackup?
    @State private var confirmRestore = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                movesSection
                backupSection
                helpSection
            }
            .navigationTitle("Moves & backups")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selectedMove) { MoveRecordView(move: $0, allMoves: moves) }
            .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json,
                          defaultFilename: "MovingSoon-backup") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json], onCompletion: importBackup)
            .confirmationDialog("Restore \(pendingBackup?.moves.count ?? 0) saved moves?", isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("Add archived copies", action: restoreBackup)
                Button("Cancel", role: .cancel) { pendingBackup = nil }
            } message: { Text("Your existing moves stay intact. Nearby reminders and optional Census lookups are not enabled by a restore.") }
            .alert("MovingSoon", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    private var movesSection: some View {
        Section {
            if moves.isEmpty { Text("Your saved moves will appear here.").foregroundStyle(.secondary) }
            ForEach(moves) { move in
                Button { selectedMove = move } label: { moveRow(move) }
                    .foregroundStyle(.primary)
            }
        } header: { Text("Your moves") }
    }

    private func moveRow(_ move: Move) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(move.destinationNeighborhood ?? move.destinationZip).font(.headline)
            Text("\(move.phase.rawValue) · \(move.effectiveAnchorDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("\(move.completedCount) of \(move.totalCount) completed")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var backupSection: some View {
        Section {
            Button("Export all moves as backup", systemImage: "square.and.arrow.up", action: exportBackup)
                .disabled(moves.isEmpty)
            Button("Restore a backup", systemImage: "square.and.arrow.down") { importing = true }
        } header: { Text("Share and backup") } footer: {
            Text("Backups include household answers, account names, notes and progress. Keep them somewhere private. Restore adds archived copies, preserves your current moves, and leaves network lookups and nearby reminders off. It does not synchronize devices.")
        }
    }

    private var helpSection: some View {
        Section {
            Link("Support website", destination: SupportLinks.contact)
            Link("GitHub support", destination: SupportLinks.github)
            Link("Email support", destination: SupportLinks.email)
            Link("Privacy policy", destination: SupportLinks.privacy)
            Text("MovingSoon keeps your checklist locally. Provider websites handle the address updates; dates you enter do not change orders or renewals.")
                .font(.caption).foregroundStyle(.secondary)
        } header: { Text("Help") }
    }

    private func exportBackup() {
        do {
            exportDocument = ChecklistFile(data: try MoveBackupService.export(moves))
            exporting = true
        } catch { message = error.localizedDescription }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            pendingBackup = try MoveBackupService.readBackup(at: url)
            confirmRestore = true
        } catch { message = error.localizedDescription }
    }

    private func restoreBackup() {
        guard let backup = pendingBackup else { return }
        do {
            let restored = try MoveBackupService.restore(backup, in: context)
            message = "Restored \(restored.count) archived moves. Open one to review it or make it active."
            pendingBackup = nil
        } catch { message = error.localizedDescription }
    }
}

struct MoveRecordView: View {
    let move: Move
    let allMoves: [Move]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingActivation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(move.effectiveAnchorDate.formatted(date: .long, time: .omitted))
                    Text("\(move.completedCount) of \(move.totalCount) completed")
                    ShareLink(item: MoveBackupService.checklistText(for: move)) {
                        Label("Share checklist", systemImage: "square.and.arrow.up")
                    }
                    if move.phase != .active {
                        Button("Make this my active move") { confirmingActivation = true }
                    }
                } footer: { Text("Shared checklists include task names, assignments and notes. Share only with people you trust.") }
                ForEach(TaskCategory.allCases, id: \.self) { category in
                    let tasks = move.tasks.filter { $0.category == category }
                    if !tasks.isEmpty {
                        Section(category.rawValue) {
                            ForEach(tasks) { task in
                                Label(task.title, systemImage: task.status == .completed ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                }
            }
            .navigationTitle(move.destinationNeighborhood ?? move.destinationZip)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Use this move?", isPresented: $confirmingActivation, titleVisibility: .visible) {
                Button("Make active") {
                    if MoveLifecycleService.activate(move, among: allMoves, in: context) { dismiss() }
                }
            } message: {
                Text("Your current move will be archived with its progress intact. Nearby reminders require a fresh choice in reminder settings.")
            }
        }
    }
}


struct TaskAssignmentButton: View {
    let task: ChecklistTask
    @Environment(\.modelContext) private var context
    @State private var editing = false
    @State private var draft = ""
    var body: some View {
        Button(task.assignee.map { "Handled by: \($0)" } ?? "Assign to someone") {
            draft = task.assignee ?? ""; editing = true
        }
        .sheet(isPresented: $editing) {
            NavigationStack {
                Form {
                    TextField("Name or initials", text: $draft)
                        .accessibilityLabel("Person handling this task")
                    Text("This label stays on this device and appears in shared checklists. It doesn't send a notification or share live updates.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .navigationTitle("Who's handling this?")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editing = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if ChecklistActions.perform(in: context, move: task.move, mutation: {
                                let name = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
                                task.assignee = name.isEmpty ? nil : name
                            }) { editing = false }
                        }
                    }
                }
            }
        }
    }
}
