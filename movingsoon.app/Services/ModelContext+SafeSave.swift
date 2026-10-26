// ModelContext+SafeSave.swift — logs save failures instead of silently discarding them
import SwiftData
import OSLog
import Observation

private let logger = Logger(subsystem: "com.movingsoon", category: "Persistence")

extension ModelContext {
    /// Explicit saves are atomic from the UI's perspective. Failed mutations return
    /// to the last persisted state; form drafts remain in their view's State.
    @discardableResult func saveOrLog() -> Bool {
        saveOrLog(using: { try save() })
    }

    /// A scoped operation makes failure behavior testable without global overrides.
    /// Production callers always use the real context save above.
    @discardableResult func saveOrLog(using saveOperation: () throws -> Void) -> Bool {
        // SwiftData batches property edits until pending changes are processed.
        // Register them before attempting I/O so rollback can restore the same
        // live model instances even when saving fails before Core Data is reached.
        processPendingChanges()
        let affectedModels = changedModelsArray + deletedModelsArray
        do {
            try saveOperation()
            return true
        } catch {
            rollback()
            // With relationship-backed models, rollback can clear hasChanges yet
            // leave already-observed values cached until the entity is fetched.
            // Fetch in this context so existing view references keep their identity
            // and receive the committed values, rather than borrowing backing data
            // from another context.
            var reloadedTypes: Set<ObjectIdentifier> = []
            for model in affectedModels where reloadedTypes.insert(ObjectIdentifier(type(of: model))).inserted {
                do { try reloadCommittedValues(for: model) }
                catch { logger.error("Unable to refresh saved checklist values after rollback.") }
            }
            logger.error("Unable to save checklist: \(error.localizedDescription, privacy: .private)")
            Task { @MainActor in PersistenceIssueCenter.shared.report(error) }
            return false
        }
    }

    private func reloadCommittedValues<Model: PersistentModel>(for model: Model) throws {
        _ = try fetch(FetchDescriptor<Model>())
    }
}

@MainActor @Observable final class PersistenceIssueCenter {
    static let shared = PersistenceIssueCenter()
    var message: String?
    func report(_ error: Error) {
        message = "We couldn’t save this change. Your last saved progress is intact. Check available storage and try the action again. Any open form keeps its draft."
    }
}
