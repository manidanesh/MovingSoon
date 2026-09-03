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

    /// How regionally similar the destination is to the origin (0...1, cosine similarity
    /// over a hand-engineered feature vector — see RegionalSimilarityService for why
    /// this isn't called an "embedding"). Nil if there's no origin ZIP on file.
    var regionalSimilarityScore: Double? {
        guard let originStateBucket else { return nil }
        return RegionalSimilarityService.similarity(between: originStateBucket, and: destinationStateBucket)
    }

    /// Distinct POI categories GeofenceCoordinator will watch for near the destination
    /// once location consent is granted — the pending, uncompleted tasks that carry a
    /// physical place type. Surfaced on the dashboard so location-based reminders are
    /// a visible, inspectable feature rather than an entirely silent background system.
    var trackedPOICategories: [POICategory] {
        let categories = tasks
            .filter { $0.status == .toDo }
            .compactMap { $0.poiCategory }
        return Array(Set(categories)).sorted { $0.rawValue < $1.rawValue }
    }

    /// Flags suggested-but-unconfirmed based on the destination's regional archetype
    /// (e.g. Epic/Ikon in a Mountain & Ski Corridor state). Never auto-applied to
    /// LifestyleProfile — this is a suggestion surface only. See MoveImpactEngine.
    var moveImpactCandidates: [MoveImpactItem] {
        MoveImpactEngine.candidates(
            destinationStateBucket: destinationStateBucket,
            activeFlags: lifestyleProfile?.activeFlags ?? [],
            originStateBucket: originStateBucket
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

    /// Per-category completion, sorted least-complete-first (then by nearest
    /// deadline among that category's incomplete tasks) — the ordering a user
    /// actually wants: "which category needs me next," not alphabetical.
    var categoryProgress: [CategoryProgress] {
        let grouped = Dictionary(grouping: tasks, by: { $0.category })
        let items = grouped.map { category, categoryTasks -> CategoryProgress in
            let completed = categoryTasks.filter { $0.status == .completed }.count
            let nextDueInDays = categoryTasks.filter { $0.status != .completed }.map(\.tMinusDays).min()
            return CategoryProgress(category: category, completed: completed, total: categoryTasks.count, nextDueInDays: nextDueInDays)
        }
        return items.sorted { lhs, rhs in
            if lhs.fraction != rhs.fraction { return lhs.fraction < rhs.fraction }
            switch (lhs.nextDueInDays, rhs.nextDueInDays) {
            case let (l?, r?) where l != r: return l < r
            case (nil, .some): return false
            case (.some, nil): return true
            default: return lhs.category.rawValue < rhs.category.rawValue
            }
        }
    }
}

struct CategoryProgress: Identifiable {
    var id: TaskCategory { category }
    let category: TaskCategory
    let completed: Int
    let total: Int
    let nextDueInDays: Int?

    var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}
