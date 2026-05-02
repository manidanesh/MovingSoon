// VerificationEvent.swift — Audit log entry for Paper Trail
import Foundation
import SwiftData

@Model
final class VerificationEvent {
    var id: UUID
    var timestamp: Date
    var methodRaw: String
    var notes: String?
    var task: ChecklistTask?

    init(method: VerificationMethod, notes: String? = nil) {
        self.id        = UUID()
        self.timestamp = Date()
        self.methodRaw = method.rawValue
        self.notes     = notes
    }

    var method: VerificationMethod {
        VerificationMethod(rawValue: methodRaw) ?? .manualConfirm
    }
}
