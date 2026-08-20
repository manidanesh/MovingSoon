// Move.swift — SwiftData model for an active move
import Foundation
import SwiftData
import CoreLocation

@Model
final class Move {
    var id: UUID
    var anchorDate: Date
    var originZip: String?
    var originNeighborhood: String?         // Geocoder-resolved: e.g. "Silverlake, Los Angeles, CA"
    var destinationZip: String
    var destinationNeighborhood: String?    // Geocoder-resolved: e.g. "Lowry, Denver, CO"
    var destinationStateBucket: String
    var destinationCityBucket: String?
    var createdAt: Date
    var phaseRaw: String

    // Coordinates saved during onboarding / edited in settings
    var originLatitude: Double?
    var originLongitude: Double?
    var destinationLatitude: Double?
    var destinationLongitude: Double?

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
        originNeighborhood: String? = nil,
        destinationZip: String,
        destinationNeighborhood: String? = nil,
        destinationStateBucket: String,
        destinationCityBucket: String?,
        originLatitude: Double? = nil,
        originLongitude: Double? = nil,
        destinationLatitude: Double? = nil,
        destinationLongitude: Double? = nil
    ) {
        self.id                       = UUID()
        self.anchorDate               = anchorDate
        self.originZip                = originZip
        self.originNeighborhood       = originNeighborhood
        self.destinationZip           = destinationZip
        self.destinationNeighborhood  = destinationNeighborhood
        self.destinationStateBucket   = destinationStateBucket
        self.destinationCityBucket    = destinationCityBucket
        self.createdAt                = Date()
        self.phaseRaw                 = MovePhase.active.rawValue
        self.tasks                    = []
        self.institutions             = []
        self.originLatitude           = originLatitude
        self.originLongitude          = originLongitude
        self.destinationLatitude      = destinationLatitude
        self.destinationLongitude     = destinationLongitude
    }

    // MARK: - Computed

    var destinationCoordinate: CLLocationCoordinate2D? {
        guard let lat = destinationLatitude, let lon = destinationLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var originCoordinate: CLLocationCoordinate2D? {
        guard let lat = originLatitude, let lon = originLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// State bucket for the origin zip, if one was provided. Used to bias which
    /// regional banks are surfaced first — an existing bank relationship is far
    /// more likely tied to where the user currently lives than where they're headed.
    var originStateBucket: String? {
        guard let originZip else { return nil }
        return ZipBucketService.bucket(zip: originZip).state
    }

    /// Cost-of-living comparison between origin and destination, or nil if there's
    /// no origin ZIP on file or either side falls outside the US snapshot (e.g. a
    /// Canadian province bucket). See RegionalEconomicsService for data provenance.
    var costOfLivingComparison: RegionalEconomicsService.Comparison? {
        RegionalEconomicsService.compare(
            originStateBucket: originStateBucket,
            destinationStateBucket: destinationStateBucket
        )
    }

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
