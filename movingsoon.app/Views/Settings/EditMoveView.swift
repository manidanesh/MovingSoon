// EditMoveView.swift — Edit move date and reset options
import SwiftUI
import SwiftData

struct EditMoveView: View {
    @Bindable var move: Move
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var anchorDate: Date
    @State private var showingResetConfirm = false

    init(move: Move) {
        self.move = move
        self._anchorDate = State(initialValue: move.anchorDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {

                        // MARK: Move Date
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Move Date")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)

                            DatePicker("", selection: $anchorDate, displayedComponents: .date)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .padding()
                                .background(Theme.backgroundElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // MARK: Move Info (read-only)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Move Details")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)

                            VStack(spacing: 0) {
                                infoRow(label: "From", value: move.originZip ?? "Not set")
                                Divider().background(Theme.hairline)
                                infoRow(label: "To", value: move.destinationZip)
                                Divider().background(Theme.hairline)
                                infoRow(label: "State", value: move.destinationStateBucket)
                                Divider().background(Theme.hairline)
                                infoRow(label: "Tasks", value: "\(move.completedCount) of \(move.totalCount) complete")
                            }
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // MARK: Danger Zone
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Danger Zone")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.priorityCritical)
                                .textCase(.uppercase)
                                .tracking(2)

                            Button {
                                showingResetConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Start Over")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.priorityCritical)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.priorityCritical.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Theme.priorityCritical.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text("Deletes all tasks and restarts the lifestyle interview. Your move date and ZIPs are kept.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textTertiary)
                                .lineSpacing(2)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Edit Move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        move.anchorDate = anchorDate
                        try? modelContext.save()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.accentPrimary)
                }
            }
            .confirmationDialog(
                "Start Over?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All Tasks & Restart", role: .destructive) {
                    resetMove()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all \(move.totalCount) tasks and your lifestyle profile. You'll redo the interview.")
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func resetMove() {
        // Delete all tasks
        for task in move.tasks {
            modelContext.delete(task)
        }
        move.tasks = []

        // Delete lifestyle profile — triggers re-interview on next launch
        if let profile = move.lifestyleProfile {
            modelContext.delete(profile)
        }
        move.lifestyleProfile = nil

        // Delete institutions
        for institution in move.institutions {
            modelContext.delete(institution)
        }
        move.institutions = []

        try? modelContext.save()
        dismiss()
    }
}
