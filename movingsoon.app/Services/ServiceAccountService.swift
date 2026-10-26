import Foundation
import SwiftData

struct ServiceAccountDraft {
    var providerName = ""
    var nickname = ""
    var website = ""
    var shipmentDate: Date?
    var renewalDate: Date?
    var leadDays = 3

    init(task: ChecklistTask? = nil, item: CatalogItem? = nil, calendar: Calendar = .current) {
        providerName = task?.accountProviderName ?? ""
        nickname = task?.accountNickname ?? ""
        website = task.map { $0.deepLinkURLString ?? "" } ?? item?.deepLinkURL?.absoluteString ?? ""
        shipmentDate = task?.shipmentDate(calendar: calendar)
        renewalDate = task?.renewalDate(calendar: calendar)
        leadDays = task?.reminderLeadDays ?? 3
    }
}

@MainActor enum ServiceAccountService {
    enum SaveError: LocalizedError {
        case nameRequired, duplicateName, invalidWebsite, unavailable
        var errorDescription: String? {
            switch self {
            case .nameRequired: return "Give this account a provider name so you can tell it apart from the others."
            case .duplicateName: return "An account with this name is already on your list. Use a different nickname or edit that account."
            case .invalidWebsite: return "Enter a website such as https://example.com, or leave it blank."
            case .unavailable: return "This checklist item is no longer available. Close this screen and try again."
            }
        }
    }

    private static func cleaned(_ text: String, limit: Int) -> String? {
        let result = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
        return result.isEmpty ? nil : result
    }

    private static func website(_ raw: String) throws -> String? {
        guard let text = cleaned(raw, limit: 2000) else { return nil }
        let candidate = text.contains(":") ? text : "https://" + text
        guard let parts = URLComponents(string: candidate),
              ["https", "http"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host, !host.isEmpty, host.contains("."),
              parts.user == nil, parts.password == nil, let url = parts.url else { throw SaveError.invalidWebsite }
        return url.absoluteString
    }

    private static func normalizedProvider(_ value: String?) -> String {
        (value ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "&", with: " and ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func matchesCatalogProvider(_ provider: String, task: ChecklistTask?, item: CatalogItem?) -> Bool {
        let displayTitle = item?.title ?? ""
        let suffixes = [" — ", " Membership", " Billing", " Account", " Shipping", " Address"]
        let end = suffixes.compactMap { displayTitle.range(of: $0)?.lowerBound }.min() ?? displayTitle.endIndex
        let providerTitle = String(displayTitle[..<end])
        let names = [task?.institutionName, item?.placeSearchName, item?.title,
                     providerTitle.isEmpty ? nil : providerTitle].compactMap { $0 }
            + (item?.placeNameAliases ?? [])
        return names.contains { normalizedProvider($0) == normalizedProvider(provider) }
    }

    /// A customer-entered provider must not inherit another brand's action URL or instructions.
    static func usesCatalogProvider(_ task: ChecklistTask, item suppliedItem: CatalogItem? = nil) -> Bool {
        guard let provider = cleaned(task.accountProviderName ?? "", limit: 120) else { return true }
        let item = suppliedItem ?? MoveChecklistService.catalogID(for: task).flatMap { ItemCatalog.byID[$0] }
        return matchesCatalogProvider(provider, task: task, item: item)
    }

    private static func catalogWebsite(task: ChecklistTask?, item: CatalogItem?) -> String? {
        if let url = item?.deepLinkURL?.absoluteString { return url }
        guard let task, let name = task.institutionName else { return nil }
        return task.move?.institutions.first(where: { $0.name == name })?.websiteURLString
    }

    /// Also protects accounts renamed by older app versions, which retained their
    /// former catalog website without recording a deliberate website choice.
    static func providerWebsite(for task: ChecklistTask, item suppliedItem: CatalogItem? = nil) -> URL? {
        let item = suppliedItem ?? MoveChecklistService.catalogID(for: task).flatMap { ItemCatalog.byID[$0] }
        if !usesCatalogProvider(task, item: item),
           let catalogWebsite = catalogWebsite(task: task, item: item), task.deepLinkURLString == catalogWebsite {
            return nil
        }
        return task.deepLinkURL
    }

    /// Deliberately adds another UUID for the same catalog identity. Normal catalog
    /// confirmation remains idempotent; only this explicit action creates an instance.
    @discardableResult
    static func save(_ draft: ServiceAccountDraft, task existing: ChecklistTask?, item: CatalogItem?,
                     move: Move, context: ModelContext, calendar: Calendar = .current) throws -> ChecklistTask {
        guard move.phase == .active else { throw SaveError.unavailable }
        if let existing {
            guard move.tasks.contains(where: { $0.id == existing.id }) else { throw SaveError.unavailable }
        } else if item == nil { throw SaveError.unavailable }
        let provider = cleaned(draft.providerName, limit: 120)
        let nickname = cleaned(draft.nickname, limit: 80)
        if existing == nil && provider == nil { throw SaveError.nameRequired }
        var link = try website(draft.website)
        let previousWebsite = existing?.deepLinkURLString ?? item?.deepLinkURL?.absoluteString
        if let provider, !matchesCatalogProvider(provider, task: existing, item: item),
           let defaultWebsite = catalogWebsite(task: existing, item: item),
           link == previousWebsite, link == defaultWebsite {
            // Keeping a prefilled brand URL is not choosing it for a new provider.
            // A different URL explicitly entered by the customer remains intact.
            link = nil
        }
        let baseTitle = existing?.accountBaseTitle ?? item?.title ?? existing?.title ?? "Account"
        let title = [provider ?? baseTitle, nickname].compactMap { $0 }.joined(separator: " — ")
        if let item, MoveChecklistService.accounts(for: item, in: move).contains(where: {
            $0.id != existing?.id && $0.title.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) { throw SaveError.duplicateName }

        let task: ChecklistTask
        if let existing { task = existing }
        else if let item { task = ChecklistGenerator.task(from: item) }
        else { throw SaveError.unavailable }
        let oldDraft = ServiceAccountDraft(task: task, calendar: calendar)
        let oldTitle = task.title, oldBaseTitle = task.accountBaseTitle
        let oldCatalogID = task.catalogItemID
        let oldLeadDays = task.accountReminderLeadDays
        let oldShipmentDate = task.nextShipmentDate, oldRenewalDate = task.nextRenewalDate
        let oldShipmentKey = task.nextShipmentDateOnly, oldRenewalKey = task.nextRenewalDateOnly
        let oldResponses = move.serviceResponsesJSON, oldCelebration = move.completionCelebratedAt
        // Preserve legacy identity before changing the display title used by backfill.
        if task.catalogItemID == nil { task.catalogItemID = MoveChecklistService.catalogID(for: task) }
        task.accountProviderName = provider
        task.accountNickname = nickname
        task.accountBaseTitle = baseTitle
        task.title = title
        task.deepLinkURLString = link
        task.setShipmentDate(draft.shipmentDate, calendar: calendar)
        task.setRenewalDate(draft.renewalDate, calendar: calendar)
        task.accountReminderLeadDays = min(30, max(0, draft.leadDays))
        if existing == nil {
            task.move = move
            context.insert(task)
            move.tasks.append(task)
            if let item { move.respond(to: item.canonicalID, with: .confirmed) }
            move.completionCelebratedAt = nil
        }
        do { try context.save() }
        catch {
            // Revert only this form's edits, retaining unrelated unsaved changes.
            if existing == nil {
                move.tasks.removeAll { $0.id == task.id }
                context.delete(task)
                move.serviceResponsesJSON = oldResponses
                move.completionCelebratedAt = oldCelebration
            } else {
                task.title = oldTitle
                task.accountBaseTitle = oldBaseTitle
                task.catalogItemID = oldCatalogID
                task.accountProviderName = cleaned(oldDraft.providerName, limit: 120)
                task.accountNickname = cleaned(oldDraft.nickname, limit: 80)
                task.deepLinkURLString = oldDraft.website.isEmpty ? nil : oldDraft.website
                task.nextShipmentDate = oldShipmentDate
                task.nextRenewalDate = oldRenewalDate
                task.nextShipmentDateOnly = oldShipmentKey
                task.nextRenewalDateOnly = oldRenewalKey
                task.accountReminderLeadDays = oldLeadDays
            }
            throw error
        }
        return task
    }
}

/// Shared creation/edit path: an unsuccessful save keeps the form open and
/// restores only its changes, without discarding unrelated pending work.
@MainActor enum CustomTaskService {
    enum SaveError: LocalizedError {
        case titleRequired, unavailable
        var errorDescription: String? {
            switch self {
            case .titleRequired: return "Give your checklist item a name."
            case .unavailable: return "This custom item is no longer available. Close this screen and try again."
            }
        }
    }

    @discardableResult
    static func save(title: String, category: TaskCategory, dueDate: Date, note: String,
                     task existing: ChecklistTask? = nil, move: Move, context: ModelContext,
                     calendar: Calendar = .current) throws -> ChecklistTask {
        guard move.phase == .active else { throw SaveError.unavailable }
        if let existing {
            guard existing.isUserAdded, move.tasks.contains(where: { $0.id == existing.id }) else {
                throw SaveError.unavailable
            }
        }
        let title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        guard !title.isEmpty else { throw SaveError.titleRequired }
        let task = existing ?? ChecklistTask(title: title, category: category, priority: .medium,
                                             tMinusDays: 0, isUserAdded: true)
        let oldTitle = task.title, oldCategory = task.categoryRaw, oldNote = task.customerNote
        let oldDate = task.absoluteDueDate, oldKey = task.absoluteDueDateOnly, oldOffset = task.tMinusDays
        let oldCelebration = move.completionCelebratedAt
        task.title = title
        task.categoryRaw = category.rawValue
        task.customerNote = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        task.setCustomDueDate(dueDate, calendar: calendar)
        task.tMinusDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: move.moveDate(calendar: calendar)),
                                                  to: calendar.startOfDay(for: dueDate)).day ?? 0
        if existing == nil {
            task.move = move
            context.insert(task)
            move.tasks.append(task)
            move.completionCelebratedAt = nil
        }
        do { try context.save() }
        catch {
            if existing == nil {
                move.tasks.removeAll { $0.id == task.id }
                context.delete(task)
                move.completionCelebratedAt = oldCelebration
            } else {
                task.title = oldTitle
                task.categoryRaw = oldCategory
                task.customerNote = oldNote
                task.absoluteDueDate = oldDate
                task.absoluteDueDateOnly = oldKey
                task.tMinusDays = oldOffset
            }
            throw error
        }
        return task
    }
}
