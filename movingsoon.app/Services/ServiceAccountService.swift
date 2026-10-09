import Foundation
import SwiftData

struct ServiceAccountDraft {
    var providerName = ""
    var nickname = ""
    var website = ""
    var shipmentDate: Date?
    var renewalDate: Date?
    var leadDays = 3

    init(task: ChecklistTask? = nil, item: CatalogItem? = nil) {
        providerName = task?.accountProviderName ?? ""
        nickname = task?.accountNickname ?? ""
        website = task.map { $0.deepLinkURLString ?? "" } ?? item?.deepLinkURL?.absoluteString ?? ""
        shipmentDate = task?.nextShipmentDate
        renewalDate = task?.nextRenewalDate
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
        let link = try website(draft.website)
        let baseTitle = existing?.accountBaseTitle ?? item?.title ?? existing?.title ?? "Account"
        let title = [provider ?? baseTitle, nickname].compactMap { $0 }.joined(separator: " — ")
        if let item, MoveChecklistService.accounts(for: item, in: move).contains(where: {
            $0.id != existing?.id && $0.title.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) { throw SaveError.duplicateName }

        let task: ChecklistTask
        if let existing { task = existing }
        else if let item { task = ChecklistGenerator.task(from: item) }
        else { throw SaveError.unavailable }
        let oldDraft = ServiceAccountDraft(task: task)
        let oldTitle = task.title, oldBaseTitle = task.accountBaseTitle
        let oldCatalogID = task.catalogItemID
        let oldLeadDays = task.accountReminderLeadDays
        let oldResponses = move.serviceResponsesJSON, oldCelebration = move.completionCelebratedAt
        // Preserve legacy identity before changing the display title used by backfill.
        if task.catalogItemID == nil { task.catalogItemID = MoveChecklistService.catalogID(for: task) }
        task.accountProviderName = provider
        task.accountNickname = nickname
        task.accountBaseTitle = baseTitle
        task.title = title
        task.deepLinkURLString = link
        task.nextShipmentDate = draft.shipmentDate.map { calendar.startOfDay(for: $0) }
        task.nextRenewalDate = draft.renewalDate.map { calendar.startOfDay(for: $0) }
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
                task.nextShipmentDate = oldDraft.shipmentDate
                task.nextRenewalDate = oldDraft.renewalDate
                task.accountReminderLeadDays = oldLeadDays
            }
            throw error
        }
        return task
    }
}
