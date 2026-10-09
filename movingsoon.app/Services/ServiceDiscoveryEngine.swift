import Foundation

struct ServiceSuggestion: Identifiable {
    var id: String { item.canonicalID }
    let item: CatalogItem
    let reason: String
    let rank: Int
}

/// Local, explainable review ordering. Scores order questions, never estimate
/// enrollment or personal income. Missing Census data leaves these rules usable.
@MainActor
enum ServiceDiscoveryEngine {
    static func candidates(for move: Move, area: AreaMarketComparison? = nil,
                           now: Date = Date(), includeDeferred: Bool = false) -> [ServiceSuggestion] {
        let profile = move.lifestyleProfile
        let flags = profile?.activeFlags ?? []
        let existing = Set(move.tasks.compactMap { MoveChecklistService.catalogID(for: $0) })
        let responses = move.serviceResponses
        let serviceUse = move.serviceUseResponses
        let reviewed = move.reviewedFamilies
        let originCandidates: Set<LifestyleFlag> = move.originStateBucket.map {
            Set(MoveImpactEngine.candidates(destinationStateBucket: $0, activeFlags: flags).map(\.flag))
        } ?? []
        let destinationCandidates = Set(move.moveImpactCandidates.map(\.flag))
        let preferred: Set<String> = ["paypal", "kids_childcare", "school_meal_account", "microchip",
            "pet_insurance_update", "delivery_autoship_review", "work_benefits_review", "home_security",
            "toll_ezpass", "aaa", "old_utilities_final_bill", "new_utilities_start", "landlord_forwarding"]
        let crossesState = move.originStateBucket.map {
            $0 != "US" && move.destinationStateBucket != "US" && $0 != move.destinationStateBucket
        } ?? false
        let housingChanged = area.flatMap { MoveFitEngine.housingMeasure(comparison: $0, flags: flags) }
            .map { $0.direction != .noClearDifference } ?? false

        return ChecklistGenerator.catalogForReview(for: move)
            .compactMap { item -> ServiceSuggestion? in
                guard !existing.contains(item.canonicalID) else { return nil }
                // A reviewed category is a completed memory check. Customers can
                // reopen it in Review services without changing individual answers.
                guard !reviewed.contains(item.reviewFamily) else { return nil }
                if let answer = serviceUse[item.canonicalID] {
                    if answer.answer == .doesNotUse { return nil }
                    if answer.answer == .unsure, !includeDeferred,
                       now.timeIntervalSince(answer.answeredAt) < 7 * 86400 { return nil }
                }
                if let response = responses[item.canonicalID] {
                    if response.decision == .notApplicable || response.decision == .confirmed { return nil }
                    if response.decision == .unsure && !includeDeferred,
                       now.timeIntervalSince(response.updatedAt) < 7 * 86400 { return nil }
                }
                let serviceFlags = item.requires.union(item.requiresAny)
                let explicitlyUsesService = serviceUse[item.canonicalID]?.answer == .usesService
                if !explicitlyUsesService, let flag = ItemCatalog.confirmationFlag(for: item),
                   profile?.moveImpactFeedback(for: flag) == .notRelevant { return nil }
                if !explicitlyUsesService,
                   serviceFlags.contains(where: { profile?.moveImpactFeedback(for: $0) == .notRelevant }) { return nil }
                var rank = 20
                var reason = item.topic == .general
                    ? "A quick check in \(item.reviewFamily.title.lowercased()). Add it only if it applies to you."
                    : "\(item.topic.prompt) Add this service only if you use it."
                if preferred.contains(item.id) { rank += 12 }

                switch item.discoveryContext {
                case .children:
                    if profile?.childrenAnswer == false && !explicitlyUsesService { return nil }
                    if flags.contains(.hasChildren) {
                        rank += 60
                        reason = "You told us there are children at home. Check any related accounts you use."
                        if let count = profile?.childCount {
                            reason = "You reported \(count) \(count == 1 ? "child" : "children"). Check any related accounts you use."
                        }
                    }
                case .pets:
                    if profile?.petsAnswer == false && !explicitlyUsesService { return nil }
                    if flags.contains(.hasPets) {
                        rank += 60
                        reason = "You have pets. Remember their records, deliveries and any policies you use."
                    }
                case .vehicle:
                    if !flags.isDisjoint(with: [.hasCar, .hasElectricVehicle, .hasMotorcycle, .hasMultipleCars]) {
                        rank += 45
                        reason = "You reported a vehicle. Check its accounts and address records."
                    }
                case .housing:
                    if profile?.managesUtilities == false && item.category == .utilities && !explicitlyUsesService { return nil }
                    if profile?.destinationHousing != .unknown && profile?.destinationHousing != nil {
                        rank += 35
                        reason = "Check the accounts and services you manage for your home."
                    }
                    if housingChanged && (item.reviewFamily == .home || item.reviewFamily == .insurance) {
                        rank += 5
                        reason += " Census housing estimates differ between your ZIP areas; review your own arrangements with the provider."
                    }
                case .work:
                    if !flags.isDisjoint(with: [.workFromHome, .runsBusiness, .hasFSA]) {
                        rank += 40
                        reason = "Your answers include work or benefits accounts. Check where your address is held."
                    }
                case .transition:
                    if item.id == "previous_home_policy" {
                        guard let profile, [.rent, .own].contains(profile.originHousing),
                              profile.destinationHousing != .unknown,
                              profile.originHousing != profile.destinationHousing else { return nil }
                        rank += 60
                        reason = "Your old and new housing arrangements differ. Check what needs to change on any previous-home policy."
                    } else if item.id == "landlord_forwarding" {
                        guard profile?.originHousing == .rent else { return nil }
                        rank += 65
                        reason = "You are leaving a rental. Give the previous landlord a forwarding address."
                    } else {
                        if profile?.managesUtilities == false { return nil }
                        rank += 35
                        reason = "If you manage utilities, confirm the old stop dates and new start dates separately."
                    }
                case nil: break
                }
                if item.id == "household_address_review" {
                    guard let size = profile?.householdSize, size > 1 else { return nil }
                    rank += 65
                    reason = "You said \(size) people are moving. Check whether each person's accounts and shared deliveries have been covered."
                }
                if item.id == "pet_records_review", let species = profile?.petSpecies, !species.isEmpty {
                    reason = "You mentioned \(species.map(\.displayLabel).sorted().joined(separator: ", ")). Check the records, registrations and deliveries you use for them."
                }
                if !serviceFlags.isDisjoint(with: originCandidates) {
                    rank += 25
                    reason = "Your previous region may help you recall this membership. Check whether you already use it."
                } else if !serviceFlags.isDisjoint(with: destinationCandidates) {
                    rank += 5
                    reason = "This membership may be relevant to the destination region. Check whether you already have an account."
                }
                if crossesState && [.identity, .insurance].contains(item.reviewFamily) {
                    rank += 10
                    reason += " Your move crosses a state or province boundary; check the provider's requirements."
                }
                if explicitlyUsesService {
                    rank += 80
                    reason = "You told us you use this service. Add a reminder if its address still needs updating."
                } else if move.areaInsightsEnabled == true,
                          area?.origin?.zip == move.originZip,
                          let adjustment = IncomeSuggestionEngine.adjustment(for: item.canonicalID,
                              origin: area?.origin, now: now) {
                    rank += adjustment.points
                    if adjustment.points > 0 {
                        reason += " A regional service-use study also supports reviewing this account."
                    }
                }
                return ServiceSuggestion(item: item, reason: reason, rank: rank)
            }
            .sorted { $0.rank == $1.rank ? $0.id < $1.id : $0.rank > $1.rank }
    }

    static func spotlight(for move: Move, area: AreaMarketComparison? = nil, limit: Int = 3) -> [ServiceSuggestion] {
        var families: Set<ReviewFamily> = []
        return Array(candidates(for: move, area: area).filter {
            families.insert($0.item.reviewFamily).inserted
        }.prefix(limit))
    }
}
