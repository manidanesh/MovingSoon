// CatalogItem.swift — A single addressable item in the master catalog
import Foundation

struct CatalogItem: Identifiable {
    let id: String
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
        alwaysInclude: Bool = false
    ) {
        self.id             = id
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
    }
}
