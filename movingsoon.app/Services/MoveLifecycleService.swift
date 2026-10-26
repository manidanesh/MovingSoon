import Foundation
import SwiftData

@MainActor enum MoveLifecycleService {
    @discardableResult static func archive(_ move: Move, cancelled: Bool = false,
                                           in context: ModelContext, updateReminders: Bool = true) -> Bool {
        guard !move.isDeleted, move.modelContext === context else { return false }
        return ChecklistActions.perform(in: context, move: nil, updateReminders: updateReminders) {
            move.phaseRaw = cancelled ? MovePhase.cancelled.rawValue : MovePhase.archived.rawValue
            move.locationConsentGrantedAt = nil
            move.locationConsentRequestedAt = nil
            move.locationConsentStoppedAt = Date()
        }
    }

    @discardableResult static func activate(_ move: Move, among moves: [Move],
                                            in context: ModelContext, updateReminders: Bool = true) -> Bool {
        guard !move.isDeleted, move.modelContext === context else { return false }
        let stored: [Move]
        do { stored = try context.fetch(FetchDescriptor<Move>()) }
        catch { PersistenceIssueCenter.shared.report(error); return false }
        return ChecklistActions.perform(in: context, move: move, updateReminders: updateReminders) {
            for previous in stored where previous.id != move.id && previous.phase == .active {
                previous.phaseRaw = MovePhase.archived.rawValue
                previous.locationConsentGrantedAt = nil
                previous.locationConsentRequestedAt = nil
                previous.locationConsentStoppedAt = Date()
            }
            move.phaseRaw = MovePhase.active.rawValue
            // Reactivating a move never restores old permission consent.
            move.locationConsentGrantedAt = nil
            move.locationConsentRequestedAt = nil
            move.locationConsentStoppedAt = nil
        }
    }
}
