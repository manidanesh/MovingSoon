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

    /// A moderate archetype match gets promoted to high confidence when the overall
    /// origin -> destination region is itself highly similar (WS3 of the intelligence-
    /// rework scope) — independent evidence the user's regional lifestyle patterns are
    /// likely to carry over, not just a property of the destination in isolation.
    /// Conservative on purpose: never touches an already-high match, never touches a
    /// suggestion when similarity is merely average.
    private static let similarityUpgradeThreshold = 0.75

    /// Suggested-but-unconfirmed flags for a move, based on the destination's regional
    /// archetype match. Never returns a flag already active in `activeFlags` — those
    /// are confirmed, not candidates. Ranked highest-confidence first.
    static func candidates(
        destinationStateBucket: String,
        activeFlags: Set<LifestyleFlag>,
        originStateBucket: String? = nil
    ) -> [MoveImpactItem] {
        let matches = RegionalArchetypeService.matches(forStateBucket: destinationStateBucket)
        var items: [MoveImpactItem] = []
        var seen: Set<LifestyleFlag> = []

        let regionalSimilarity: Double? = originStateBucket.map {
            RegionalSimilarityService.similarity(between: $0, and: destinationStateBucket)
        }

        for match in matches {
            guard let flags = candidateFlags[match.archetype] else { continue }
            for flag in flags {
                guard !activeFlags.contains(flag), !seen.contains(flag) else { continue }
                seen.insert(flag)

                var confidence: MoveImpactConfidence = match.strength == .high ? .inferredHigh : .suggested
                if confidence == .suggested, let regionalSimilarity, regionalSimilarity > similarityUpgradeThreshold {
                    confidence = .inferredHigh
                }

                items.append(MoveImpactItem(
                    flag: flag,
                    confidence: confidence,
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
