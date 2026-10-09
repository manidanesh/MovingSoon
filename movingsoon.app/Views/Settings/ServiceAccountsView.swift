import SwiftUI
import SwiftData

struct ServiceAccountsView: View {
    let move: Move
    let item: CatalogItem
    @Environment(\.dismiss) private var dismiss
    @State private var editing: ChecklistTask?
    @State private var adding = false

    private var accounts: [ChecklistTask] { MoveChecklistService.accounts(for: item, in: move) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Keep each provider or household account separate. Each one has its own dates and checklist progress.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    ForEach(accounts) { task in
                        Button { editing = task } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(task.title).font(.headline).foregroundStyle(Theme.textPrimary)
                                Text(task.status.rawValue).font(.caption).foregroundStyle(Theme.textSecondary)
                                AccountDatesSummaryView(task: task)
                                if task.isMuted { Text("Reminders muted").font(.caption).foregroundStyle(Theme.textSecondary) }
                            }.padding(.vertical, 4)
                        }
                    }
                    Button { adding = true } label: {
                        Label(accounts.isEmpty ? "Add an account" : "Add another account", systemImage: "plus.circle")
                    }
                } header: { Text("Your accounts") } footer: {
                    Text("Tap an account to edit it. Complete or remove individual accounts from All tasks.")
                }
            }
            .navigationTitle(item.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editing) { ServiceAccountEditorView(move: move, task: $0, item: item) }
            .sheet(isPresented: $adding) { ServiceAccountEditorView(move: move, item: item) }
        }
    }
}

struct AccountDatesSummaryView: View {
    let task: ChecklistTask
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date = task.nextShipmentDate {
                Label("Shipment: \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "shippingbox")
            }
            if let date = task.nextRenewalDate {
                Label("Renewal: \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
            }
        }.font(.caption).foregroundStyle(Theme.textSecondary)
    }
}

struct ServiceAccountEditorView: View {
    let move: Move
    let task: ChecklistTask?
    let item: CatalogItem?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ServiceAccountDraft
    @State private var hasShipment: Bool
    @State private var hasRenewal: Bool
    @State private var shipment: Date
    @State private var renewal: Date
    @State private var errorMessage: String?
    @State private var saving = false

    init(move: Move, task: ChecklistTask? = nil, item: CatalogItem? = nil) {
        self.move = move
        self.task = task
        let catalogItem = item ?? task.flatMap { MoveChecklistService.catalogID(for: $0) }.flatMap { ItemCatalog.byID[$0] }
        self.item = catalogItem
        let initial = ServiceAccountDraft(task: task, item: catalogItem)
        _draft = State(initialValue: initial)
        _hasShipment = State(initialValue: initial.shipmentDate != nil)
        _hasRenewal = State(initialValue: initial.renewalDate != nil)
        _shipment = State(initialValue: initial.shipmentDate ?? Calendar.current.startOfDay(for: Date()))
        _renewal = State(initialValue: initial.renewalDate ?? Calendar.current.startOfDay(for: Date()))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(item?.title ?? task?.accountBaseTitle ?? task?.title ?? "Account")
                        .font(.subheadline).foregroundStyle(.secondary)
                    TextField(task == nil ? "Provider or account name" : "Provider name (optional)", text: $draft.providerName)
                        .textContentType(.organizationName)
                    TextField("Nickname — e.g. Family or Cabin", text: $draft.nickname)
                    TextField("Provider website (optional)", text: $draft.website)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: { Text("Which account is this?") }
                footer: { Text("A friendly name is enough. You don't need an account number or password.") }

                Section {
                    Toggle("Next shipment", isOn: $hasShipment)
                    if hasShipment { DatePicker("Shipment date", selection: $shipment, displayedComponents: .date) }
                    Toggle("Next renewal", isOn: $hasRenewal)
                    if hasRenewal { DatePicker("Renewal date", selection: $renewal, displayedComponents: .date) }
                    if hasShipment || hasRenewal {
                        Picker("Review address ahead of time", selection: $draft.leadDays) {
                            Text("On the date").tag(0)
                            Text("1 day before").tag(1)
                            Text("3 days before").tag(3)
                            Text("7 days before").tag(7)
                            Text("14 days before").tag(14)
                            Text("30 days before").tag(30)
                        }
                    }
                } header: { Text("Dates to remember (optional)") }
                footer: {
                    Text("Use the dates shown by your provider. These reminders help you review your address before the event; they don't change orders or renewals. Update the next date when you need another reminder.")
                }
                Section {
                    if task?.status == .completed {
                        Text("This address update is complete. Its reminders stay off unless you reopen the task.")
                    } else {
                        Text("Snooze and Mute apply to these reminders too. Marking this address update done stops its reminders.")
                    }
                    Text("Your account names and dates are saved on this device.")
                }.font(.caption).foregroundStyle(.secondary)
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(Theme.priorityCritical) } }
            }
            .navigationTitle(task == nil ? "Add account" : "Account & dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(saving || (task == nil && draft.providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
        }
    }

    private func save() {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        draft.shipmentDate = hasShipment ? shipment : nil
        draft.renewalDate = hasRenewal ? renewal : nil
        do {
            try ServiceAccountService.save(draft, task: task, item: item, move: move, context: modelContext)
            SmartReminderService.shared.reschedule(for: move)
            LocationManager.shared.attach(move, context: modelContext)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
