// ChecklistGenerator.swift — Filters the catalog by lifestyle flags → ChecklistTask array
import Foundation
import SwiftData

enum ChecklistGenerator {

    /// Generate tasks for a move based on its lifestyle profile and selected institutions.
    static func generate(for move: Move, profile: LifestyleProfile, institutions: [FinancialInstitution]) -> [ChecklistTask] {
        let flags = profile.activeFlags
        var tasks: [ChecklistTask] = []

        // 1. Catalog-based tasks
        for item in ItemCatalog.all {
            guard shouldInclude(item, flags: flags) else { continue }
            tasks.append(task(from: item))
        }

        // 2. Institution-specific tasks (per bank / card / investment)
        for institution in institutions {
            let task = ChecklistTask(
                title: "Update address with \(institution.name)",
                category: .financial,
                priority: priorityFor(institution.institutionType),
                tMinusDays: tMinusFor(institution.institutionType),
                deepLinkURL: institution.websiteURL
            )
            task.institutionName     = institution.name
            task.institutionInitials = institution.initials
            task.institutionColorHex = institution.colorHex
            if institution.institutionType == .bank || institution.institutionType == .creditUnion {
                task.poiCategory = .bank
            }
            tasks.append(task)
        }

        // 3. Deduplicate by id (hero USPS always first)
        let hero = tasks.filter { $0.isHeroItem }
        let rest = tasks.filter { !$0.isHeroItem }
        return hero + rest
    }

    // MARK: - Filter Logic

    private static func shouldInclude(_ item: CatalogItem, flags: Set<LifestyleFlag>) -> Bool {
        if item.alwaysInclude { return true }

        // Must have ALL required flags
        if !item.requires.isEmpty && !item.requires.isSubset(of: flags) { return false }

        // Must have ANY of requiresAny (if specified)
        if !item.requiresAny.isEmpty && item.requiresAny.isDisjoint(with: flags) { return false }

        // Must not have any excluded flags
        if !item.excludes.isEmpty && !item.excludes.isDisjoint(with: flags) { return false }

        // If no constraints at all, include
        if item.requires.isEmpty && item.requiresAny.isEmpty { return true }

        return true
    }

    // MARK: - CatalogItem → ChecklistTask

    private static func task(from item: CatalogItem) -> ChecklistTask {
        let t = ChecklistTask(
            title: item.title,
            category: item.category,
            priority: item.priority,
            tMinusDays: item.tMinusDays,
            isHeroItem: item.isHeroItem,
            deepLinkURL: item.deepLinkURL
        )
        t.institutionColorHex = item.brandColorHex
        // Store emoji as institutionInitials (repurposed for display)
        t.institutionInitials = item.emoji
        t.poiCategory = item.poiCategory
        return t
    }

    // MARK: - Institution helpers

    private static func priorityFor(_ type: InstitutionType) -> TaskPriority {
        switch type {
        case .bank, .creditUnion, .mortgage: return .critical
        case .creditCard, .studentLoan:      return .high
        case .investment:                    return .high
        }
    }

    private static func tMinusFor(_ type: InstitutionType) -> Int {
        switch type {
        case .bank, .creditUnion, .mortgage: return -14
        case .creditCard, .studentLoan:      return -7
        case .investment:                    return 7
        }
    }
}
