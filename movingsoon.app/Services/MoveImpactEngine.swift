// MoveImpactEngine.swift — Turns a destination's regional archetype into pre-surfaced,
// never-auto-checked flag suggestions.
//
// Design note: earlier research sketched a "transfer / cancel-and-establish / review"
// action on each suggestion. That taxonomy describes what happens to a membership the
// user has *already confirmed* (e.g. Farm Bureau is cancel-and-establish because it's
// state-federated) — it doesn't cleanly apply here, since a MoveImpactItem is by
// definition a flag the user hasn't confirmed yet. Forcing that field in would fit the
// code to the earlier diagram rather than to what's actually true, so it's dropped;
// the transfer-vs-establish distinction already lives in each CatalogItem's own title
// (see "Farm Bureau — New State Membership Required").
import Foundation

enum MoveImpactConfidence {
    case inferredHigh   // destination archetype match strength: .high
    case suggested      // destination archetype match strength: .moderate
}

struct MoveImpactItem: Identifiable {
    var id: LifestyleFlag { flag }
    let flag: LifestyleFlag
    let confidence: MoveImpactConfidence
    let archetype: RegionalArchetype
    /// User-facing reason, e.g. "Denver, CO is a Mountain & Ski Corridor region."
    let rationale: String
}

enum MoveImpactEngine {

    /// Candidate flags per archetype — only populated where a real, specific
    /// LifestyleFlag exists to suggest. Several archetypes (coastal, urban transit,
    /// suburban youth-sports, college town) have no dedicated flag precise enough to
    /// suggest with confidence yet, so they're intentionally absent here rather than
    /// forcing a weak guess. See the Move Intelligence Engine report for why.
    private static let candidateFlags: [RegionalArchetype: [LifestyleFlag]] = [
        .mountainSkiCorridor:    [.hasEpicPass, .hasIkonPass],
        .lakeBoatingBelt:        [.usesFreedomBoatClub, .usesCarefreeBoatClub],
        .golfRetirementCorridor: [.usesInvitedClubs, .usesTroonManagedClub, .livesInDelWebbCommunity],
        .ranchWesternHeritage:   [.usesTractorSupplyNeighborsClub, .hasFarmBureauMembership],
        .huntingFishingHeritage: [.usesBassProCabelasClub, .hasConservationOrgMembership, .hasFarmBureauMembership],
    ]

    /// Suggested-but-unconfirmed flags for a move, based on the destination's regional
    /// archetype match. Never returns a flag already active in `activeFlags` — those
    /// are confirmed, not candidates. Ranked highest-confidence first.
    static func candidates(destinationStateBucket: String, activeFlags: Set<LifestyleFlag>) -> [MoveImpactItem] {
        let matches = RegionalArchetypeService.matches(forStateBucket: destinationStateBucket)
        var items: [MoveImpactItem] = []
        var seen: Set<LifestyleFlag> = []

        for match in matches {
            guard let flags = candidateFlags[match.archetype] else { continue }
            for flag in flags {
                guard !activeFlags.contains(flag), !seen.contains(flag) else { continue }
                seen.insert(flag)
                items.append(MoveImpactItem(
                    flag: flag,
                    confidence: match.strength == .high ? .inferredHigh : .suggested,
                    archetype: match.archetype,
                    rationale: "This move includes \(match.archetype.displayName) — worth checking if this applies to you."
                ))
            }
        }

        return items.sorted { lhs, rhs in
            switch (lhs.confidence, rhs.confidence) {
            case (.inferredHigh, .suggested): return true
            case (.suggested, .inferredHigh): return false
            default: return lhs.flag.rawValue < rhs.flag.rawValue
            }
        }
    }
}
