// ModelContext+SafeSave.swift — logs save failures instead of silently discarding them
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.movingsoon", category: "Persistence")

extension ModelContext {
    /// `try? save()` swallowed failures with no diagnostic trail. This logs instead —
    /// there's still nothing actionable to show the user mid-gesture, but a failed save
    /// (disk full, corrupted store) is now visible in device logs rather than invisible.
    func saveOrLog() {
        do {
            try save()
        } catch {
            logger.error("modelContext.save() failed: \(error.localizedDescription)")
        }
    }
}
