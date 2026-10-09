import Foundation
import SwiftData

@MainActor
enum MoveChecklistService {
    /// A conservative bridge for existing stores, where tasks predate catalog IDs.
    static func catalogID(for task: ChecklistTask) -> String? {
        if let id = task.catalogItemID { return ItemCatalog.byID[id]?.canonicalID ?? id }
        guard !task.isUserAdded else { return nil }
        if let name = task.institutionName {
            let matches = task.move?.institutions.filter { $0.name == name } ?? []
            guard matches.count == 1, let institution = matches.first else { return nil }
            return "institution:\(institution.institutionType.rawValue):\(institution.name)"
        }
        return ItemCatalog.legacyItem(titled: task.title)?.canonicalID
    }

    static func contains(_ item: CatalogItem, in move: Move) -> Bool {
        !accounts(for: item, in: move).isEmpty
    }

    static func accounts(for item: CatalogItem, in move: Move) -> [ChecklistTask] {
        move.tasks.filter { catalogID(for: $0) == item.canonicalID }
            .sorted { $0.title == $1.title ? $0.id.uuidString < $1.id.uuidString
                : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func backfillCatalogIDs(for move: Move) {
        // Preserve saved answers when the two legacy children's-box definitions
        // are shown as one service. Keep the more recent explicit answer.
        var responses = move.serviceResponses
        if let old = responses["kids_crate_box"],
           responses["kids_activity_box"].map({ $0.updatedAt < old.updatedAt }) ?? true {
            responses["kids_activity_box"] = old
            move.serviceResponses = responses
        }
        var useResponses = move.serviceUseResponses
        if let old = useResponses["kids_crate_box"],
           useResponses["kids_activity_box"].map({ $0.answeredAt < old.answeredAt }) ?? true {
            useResponses["kids_activity_box"] = old
            move.serviceUseResponses = useResponses
        }
        for task in move.tasks where !task.isUserAdded {
            guard let id = catalogID(for: task) else { continue }
            if task.catalogItemID == nil { task.catalogItemID = id }
            if let item = ItemCatalog.byID[id] {
                if task.moveActionRaw != item.moveAction.rawValue { task.moveActionRaw = item.moveAction.rawValue }
                if !task.hasAccountDetails && item.legacyTitles.contains(task.title) { task.title = item.title }
                // An old grouped entry must not keep sending every member to one brand.
                if !task.hasAccountDetails, let url = task.deepLinkURLString, item.obsoleteDeepLinks.contains(url) {
                    task.deepLinkURLString = item.deepLinkURL?.absoluteString
                }
            }
        }
    }

    @discardableResult
    static func confirm(_ item: CatalogItem, for move: Move, in context: ModelContext) -> ChecklistTask {
        move.respond(to: item.canonicalID, with: .confirmed)
        // Retain explicitly confirmed enrollment in the existing flag store when
        // the catalog has an unambiguous service flag. Never infer a household fact.
        let householdFlags: Set<LifestyleFlag> = [
            .hasChildren, .hasPets, .hasPartner, .isOwning, .isRenting, .hasCar,
            .hasMotorcycle, .hasMultipleCars, .hasElectricVehicle, .usesRideShare,
            .workFromHome, .runsBusiness, .isRetired, .isVeteran, .livesInHouseOrTownhouse
        ]
        if let flag = ItemCatalog.confirmationFlag(for: item) {
            move.lifestyleProfile?.set(flag, to: true)
        } else if item.requires.count == 1, let flag = item.requires.first,
                  !householdFlags.contains(flag), !PostalCodeService.geographicFlags.contains(flag) {
            move.lifestyleProfile?.set(flag, to: true)
        }
        if let existing = move.tasks.first(where: { catalogID(for: $0) == item.canonicalID }) {
            existing.catalogItemID = item.canonicalID
            existing.needsLocationReview = false
            context.saveOrLog()
            return existing
        }
        let task = ChecklistGenerator.task(from: item)
        task.move = move
        context.insert(task)
        move.tasks.append(task)
        // A later addition makes the move incomplete again, but does not reset progress.
        move.completionCelebratedAt = nil
        context.saveOrLog()
        return task
    }

    static func recordDismissal(_ task: ChecklistTask, for move: Move) {
        if let id = catalogID(for: task) {
            task.catalogItemID = id
            let hasOtherAccounts = move.tasks.contains { $0.id != task.id && catalogID(for: $0) == id }
            move.respond(to: id, with: hasOtherAccounts ? .confirmed : .notApplicable)
        }
    }

    static func addRelevantTasks(for move: Move, in context: ModelContext) {
        let flags = move.lifestyleProfile?.activeFlags ?? []
        for item in ChecklistGenerator.matchingItems(for: move, flags: flags) where !contains(item, in: move) {
            let task = ChecklistGenerator.task(from: item)
            task.move = move
            context.insert(task)
            move.tasks.append(task)
            move.completionCelebratedAt = nil
        }
        context.saveOrLog()
    }

    /// Keep earlier work when a location changes, but make outdated automatic
    /// geography matches visible for review instead of silently dropping them.
    static func flagLocationChanges(for move: Move) {
        let responses = move.serviceResponses
        let contexts = PostalCodeService.contexts(for: move, flags: move.lifestyleProfile?.activeFlags ?? [])
        for task in move.tasks where task.status != .completed && !task.isUserAdded {
            guard let id = catalogID(for: task), let item = ItemCatalog.byID[id] else { continue }
            task.needsLocationReview = responses[id]?.decision != .confirmed
                && !PostalCodeService.canReview(item, contexts: contexts)
        }
    }

    @discardableResult
    static func addCustom(title: String, family: ReviewFamily, dueDate: Date, note: String,
                          to move: Move, in context: ModelContext) -> ChecklistTask? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let offset = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: move.anchorDate),
            to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
        let categories: [ReviewFamily: TaskCategory] = [
            .identity: .government, .money: .financial, .home: .utilities,
            .insurance: .insurance, .family: .education, .healthPets: .healthcare,
            .shopping: .subscriptions, .memberships: .other, .travel: .travel, .work: .employer
        ]
        let task = ChecklistTask(title: title, category: categories[family] ?? .other,
                                 priority: .medium, tMinusDays: offset, isUserAdded: true)
        task.customerNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        task.absoluteDueDate = Calendar.current.startOfDay(for: dueDate)
        task.move = move
        context.insert(task)
        move.tasks.append(task)
        move.completionCelebratedAt = nil
        context.saveOrLog()
        return task
    }
}
