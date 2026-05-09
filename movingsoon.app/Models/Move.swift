// Move.swift — SwiftData model for an active move
import Foundation
import SwiftData

@Model
final class Move {
    var id: UUID
    var anchorDate: Date
    var originZip: String?
    var destinationZip: String
    var destinationStateBucket: String
    var destinationCityBucket: String?
    var createdAt: Date
    var phaseRaw: String

    @Relationship(deleteRule: .cascade)
    var tasks: [ChecklistTask]

    @Relationship(deleteRule: .cascade)
    var institutions: [FinancialInstitution]

    @Relationship(deleteRule: .nullify)
    var lifestyleProfile: LifestyleProfile?

    // Location consent — set when user grants 30-day location access
    var locationConsentGrantedAt: Date?

    init(
        anchorDate: Date,
        originZip: String?,
        destinationZip: String,
        destinationStateBucket: String,
        destinationCityBucket: String?
    ) {
        self.id                     = UUID()
        self.anchorDate             = anchorDate
        self.originZip              = originZip
        self.destinationZip         = destinationZip
        self.destinationStateBucket = destinationStateBucket
        self.destinationCityBucket  = destinationCityBucket
        self.createdAt              = Date()
        self.phaseRaw               = MovePhase.active.rawValue
        self.tasks                  = []
        self.institutions           = []
    }

    // MARK: - Computed

    var personaKey: PersonaKey {
        guard let profile = lifestyleProfile else { return .activeProfessional }
        if profile.has(.hasChildren) { return .familyWithKids }
        if profile.has(.isRetired) || profile.has(.hasMedicare) { return .retiree }
        if profile.has(.hasStudentLoans) && !profile.has(.hasPartner) { return .collegeGrad }
        if profile.has(.hasPartner) { return .youngCouple }
        return .activeProfessional
    }

    var phase: MovePhase {
        MovePhase(rawValue: phaseRaw) ?? .active
    }

    var daysUntilMove: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: anchorDate).day ?? 0
    }

    var completedCount: Int { tasks.filter { $0.status == .completed }.count }
    var totalCount: Int { tasks.count }

    var completionFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}
