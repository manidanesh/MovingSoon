// CatalogItem.swift — A single addressable item in the master catalog
import Foundation

struct CatalogItem: Identifiable {
    let id: String
    let canonicalID: String
    let title: String
    let emoji: String
    let category: TaskCategory
    let priority: TaskPriority
    let tMinusDays: Int
    let deepLinkURL: URL?
    let brandColorHex: String
    let isHeroItem: Bool
    /// ALL of these flags must be active for this item to appear
    let requires: Set<LifestyleFlag>
    /// ANY of these flags triggers this item (OR logic)
    let requiresAny: Set<LifestyleFlag>
    /// If ANY of these are active, item is excluded
    let excludes: Set<LifestyleFlag>
    /// Always show regardless of flags
    let alwaysInclude: Bool
    /// Used for geofencing reminders
    let poiCategory: POICategory?
    let placeSearchName: String?
    let placeNameAliases: [String]
    let reviewFamily: ReviewFamily
    let discoveryContext: DiscoveryContext?
    let requiresConfirmation: Bool
    let moveAction: ServiceMoveAction
    let topic: CatalogTopic
    let searchTerms: [String]
    let movingTip: String?
    let legacyTitles: [String]
    let obsoleteDeepLinks: [String]

    init(
        id: String,
        title: String,
        emoji: String,
        category: TaskCategory,
        priority: TaskPriority,
        tMinusDays: Int = 0,
        deepLinkURL: URL? = nil,
        brandColorHex: String = "#626567",
        isHeroItem: Bool = false,
        requires: Set<LifestyleFlag> = [],
        requiresAny: Set<LifestyleFlag> = [],
        excludes: Set<LifestyleFlag> = [],
        alwaysInclude: Bool = false,
        poiCategory: POICategory? = nil,
        placeSearchName: String? = nil,
        placeNameAliases: [String] = [],
        reviewFamily: ReviewFamily? = nil,
        discoveryContext: DiscoveryContext? = nil,
        requiresConfirmation: Bool = false,
        moveAction: ServiceMoveAction = .updateAddress,
        canonicalID: String? = nil,
        topic: CatalogTopic? = nil,
        searchTerms: [String] = [],
        movingTip: String? = nil,
        legacyTitles: [String] = [],
        obsoleteDeepLinks: [String] = []
    ) {
        self.id             = id
        self.canonicalID = canonicalID ?? id
        self.title          = title
        self.emoji          = emoji
        self.category       = category
        self.priority       = priority
        self.tMinusDays     = tMinusDays
        self.deepLinkURL    = deepLinkURL
        self.brandColorHex  = brandColorHex
        self.isHeroItem     = isHeroItem
        self.requires       = requires
        self.requiresAny    = requiresAny
        self.excludes       = excludes
        self.alwaysInclude  = alwaysInclude
        self.poiCategory    = poiCategory
        self.placeSearchName = placeSearchName
        self.placeNameAliases = placeNameAliases
        self.reviewFamily = reviewFamily ?? Self.defaultFamily(for: category)
        self.discoveryContext = discoveryContext
        self.requiresConfirmation = requiresConfirmation
        self.moveAction = moveAction
        self.topic = topic ?? CatalogTopic.forID(id)
        self.searchTerms = searchTerms
        self.movingTip = movingTip
        self.legacyTitles = legacyTitles
        self.obsoleteDeepLinks = obsoleteDeepLinks
    }

    var moveGuidance: String? { movingTip ?? topic.movingTip }

    func matchesSearch(_ query: String) -> Bool {
        func words(_ value: String) -> [String] {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        }
        let terms = words(query)
        guard !terms.isEmpty else { return true }
        let fields = [title, reviewFamily.title, topic.title, topic.searchTerms] + searchTerms
        let indexed = words(fields.joined(separator: " "))
        let haystack = indexed.joined(separator: " ")
        // Accept both "Stitch Fix" and "stitchfix", as well as multi-word topics.
        return terms.allSatisfy { haystack.contains($0) } || indexed.joined().contains(terms.joined())
    }

    private static func defaultFamily(for category: TaskCategory) -> ReviewFamily {
        switch category {
        case .postal, .government: return .identity
        case .financial: return .money
        case .utilities: return .home
        case .insurance: return .insurance
        case .education: return .family
        case .healthcare: return .healthPets
        case .employer, .legal, .estate, .digital: return .work
        case .travel: return .travel
        case .subscriptions: return .shopping
        case .other: return .memberships
        }
    }
}
