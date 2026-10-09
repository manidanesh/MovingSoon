// ChecklistGenerator.swift — Filters the catalog by lifestyle flags → ChecklistTask array
import Foundation
import SwiftData

enum ChecklistGenerator {

    /// Generate tasks for a move based on its lifestyle profile and selected institutions.
    static func generate(for move: Move, profile: LifestyleProfile, institutions: [FinancialInstitution]) -> [ChecklistTask] {
        let flags = profile.activeFlags
        var tasks: [ChecklistTask] = []

        // 1. Catalog-based tasks
        for item in matchingItems(for: move, flags: flags) {
            tasks.append(task(from: item))
        }

        // 2. Institution-specific tasks (per bank / card / investment)
        let responses = move.serviceResponses
        for institution in institutions {
            let task = task(from: institution)
            if let id = task.catalogItemID, let decision = responses[id]?.decision,
               decision == .notApplicable || decision == .unsure { continue }
            tasks.append(task)
        }

        // 3. Hero items first; catalog duplicates were removed during matching.
        let hero = tasks.filter { $0.isHeroItem }
        let rest = tasks.filter { !$0.isHeroItem }
        return hero + rest
    }

    // MARK: - Filter Logic

    /// Catalog items that would be included for a given flag set — shared by the real
    /// generator below and by any UI that needs an accurate (not heuristic) task count.
    static func matchingItems(flags: Set<LifestyleFlag>) -> [CatalogItem] {
        uniqueServices(ItemCatalog.all.filter { shouldInclude($0, flags: flags) })
    }

    static func catalogForReview(for move: Move) -> [CatalogItem] {
        let contexts = PostalCodeService.contexts(for: move, flags: move.lifestyleProfile?.activeFlags ?? [])
        return uniqueServices(ItemCatalog.all.filter { PostalCodeService.canReview($0, contexts: contexts) })
    }

    static func uniqueServices(_ items: [CatalogItem]) -> [CatalogItem] {
        var seen: Set<String> = []
        return items.filter { seen.insert($0.canonicalID).inserted }
    }

    /// Evaluate each end of the move independently. A Canadian destination must not
    /// suppress the US accounts that still need attention at the previous home.
    static func matchingItems(for move: Move, flags: Set<LifestyleFlag>) -> [CatalogItem] {
        let responses = move.serviceResponses
        let serviceUse = move.serviceUseResponses
        let contexts = PostalCodeService.contexts(for: move, flags: flags)
        return uniqueServices(ItemCatalog.all.filter { item in
            if let decision = responses[item.canonicalID]?.decision,
               decision == .notApplicable || decision == .unsure { return false }
            if responses[item.canonicalID]?.decision == .confirmed { return true }
            if let answer = serviceUse[item.canonicalID]?.answer,
               answer == .doesNotUse || answer == .unsure { return false }
            if move.lifestyleProfile?.managesUtilities == false,
               ["electric", "gas", "water", "trash", "internet"].contains(item.id) { return false }
            return contexts.contains { shouldInclude(item, flags: $0) }
        })
    }

    static func shouldInclude(_ item: CatalogItem, flags: Set<LifestyleFlag>) -> Bool {
        if item.requiresConfirmation { return false }
        // Broad facts such as "has children" may gate a relevant family-service
        // question, but named providers require their own explicit confirmation.
        if let confirmationFlag = ItemCatalog.confirmationFlag(for: item), !flags.contains(confirmationFlag) {
            return false
        }

        // Excludes ALWAYS trumps everything else (even alwaysInclude)
        if !item.excludes.isEmpty && !item.excludes.isDisjoint(with: flags) { return false }

        if item.alwaysInclude { return true }

        // Must have ALL required flags
        if !item.requires.isEmpty && !item.requires.isSubset(of: flags) { return false }

        // Must have ANY of requiresAny (if specified)
        if !item.requiresAny.isEmpty && item.requiresAny.isDisjoint(with: flags) { return false }

        // If no constraints at all, include
        if item.requires.isEmpty && item.requiresAny.isEmpty { return true }

        return true
    }

    // MARK: - CatalogItem → ChecklistTask

    static func task(from item: CatalogItem) -> ChecklistTask {
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
        t.catalogItemID = item.canonicalID
        t.moveActionRaw = item.moveAction.rawValue
        return t
    }

    static func task(from institution: FinancialInstitution) -> ChecklistTask {
        let task = ChecklistTask(title: institution.name, category: .financial,
            priority: priorityFor(institution.institutionType), tMinusDays: tMinusFor(institution.institutionType),
            deepLinkURL: institution.websiteURL)
        task.catalogItemID = "institution:\(institution.institutionType.rawValue):\(institution.name)"
        task.institutionName = institution.name
        task.institutionInitials = institution.initials
        task.institutionColorHex = institution.colorHex
        if institution.institutionType == .bank || institution.institutionType == .creditUnion { task.poiCategory = .bank }
        return task
    }

    // MARK: - Institution helpers

    private static func priorityFor(_ type: InstitutionType) -> TaskPriority {
        switch type {
        case .bank, .creditUnion, .mortgage:   return .critical
        case .creditCard, .studentLoan:        return .high
        case .investment:                      return .high
        case .autoLoan:                        return .high
        }
    }

    private static func tMinusFor(_ type: InstitutionType) -> Int {
        switch type {
        case .bank, .creditUnion, .mortgage:   return -14
        case .creditCard, .studentLoan:        return -7
        case .investment:                      return 7
        case .autoLoan:                        return -7
        }
    }
}
