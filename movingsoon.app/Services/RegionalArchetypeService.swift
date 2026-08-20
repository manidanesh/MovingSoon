// RegionalArchetypeService.swift — On-device regional lifestyle archetype matching (no network call)
//
// Generalizes the ski-pass state mapping into a broader pattern: certain regions
// cluster around a small set of recreation-and-membership signatures. Unlike
// RegionalEconomicsService's income/home-value data (pulled live from Census/Zillow),
// this table is hand-curated — there is no free bulk API for "who skis" or "who
// boats" the way there is for household income. It should be treated the same way
// KnownInstitutions.swift's bank footprints are: periodically refreshed by a human,
// not auto-updating.
//
// A state can — and often does — match more than one archetype (e.g. a ZIP in Bend,
// OR is genuinely both Mountain/Ski Corridor and Lake & Boating adjacent). Matching
// returns a ranked set, not a single label, and each match carries a strength so
// downstream candidate generation can grade its own confidence accordingly.
import Foundation

enum RegionalArchetype: String, CaseIterable {
    case mountainSkiCorridor
    case lakeBoatingBelt
    case coastalBeachClub
    case golfRetirementCorridor
    case urbanDenseTransit
    case suburbanYouthSportsBelt
    case ranchWesternHeritage
    case huntingFishingHeritage
    case collegeTown

    var displayName: String {
        switch self {
        case .mountainSkiCorridor:    return "Mountain & Ski Corridor"
        case .lakeBoatingBelt:        return "Lake & Boating Belt"
        case .coastalBeachClub:       return "Coastal & Beach Club"
        case .golfRetirementCorridor: return "Golf & Retirement Corridor"
        case .urbanDenseTransit:      return "Urban Dense / Transit"
        case .suburbanYouthSportsBelt:return "Suburban Youth-Sports Belt"
        case .ranchWesternHeritage:   return "Ranch & Western Heritage"
        case .huntingFishingHeritage: return "Hunting & Fishing Heritage"
        case .collegeTown:            return "College Town"
        }
    }
}

enum ArchetypeMatchStrength {
    case high       // e.g. CO/UT for Mountain & Ski — the archetype's anchor states
    case moderate    // real signal, but state-level grain is a proxy, not a certainty
}

struct ArchetypeMatch {
    let archetype: RegionalArchetype
    let strength: ArchetypeMatchStrength
}

enum RegionalArchetypeService {

    /// Ranked archetype matches for a state bucket (as returned by ZipBucketService.bucket(zip:).state).
    /// Empty array — not a fallback archetype — for states with no strong regional signal
    /// in this table; that's the honest answer, not a gap to paper over.
    static func matches(forStateBucket bucket: String) -> [ArchetypeMatch] {
        table[bucket] ?? []
    }

    // MARK: - Hand-curated state → archetype table

    private static let table: [String: [ArchetypeMatch]] = [
        // Mountain & Ski Corridor — high confidence: the two states with major
        // anchors on both Epic and Ikon. See the Location Intelligence report's
        // full resort table for the underlying Vail/Alterra footprint.
        "CO": [.init(archetype: .mountainSkiCorridor, strength: .high)],
        "UT": [.init(archetype: .mountainSkiCorridor, strength: .high)],
        "VT": [.init(archetype: .mountainSkiCorridor, strength: .high)],
        "WY": [.init(archetype: .mountainSkiCorridor, strength: .high), .init(archetype: .ranchWesternHeritage, strength: .high)],
        "MT": [.init(archetype: .mountainSkiCorridor, strength: .high), .init(archetype: .ranchWesternHeritage, strength: .high), .init(archetype: .huntingFishingHeritage, strength: .high)],
        "ID": [.init(archetype: .mountainSkiCorridor, strength: .moderate), .init(archetype: .ranchWesternHeritage, strength: .moderate)],
        "NH": [.init(archetype: .mountainSkiCorridor, strength: .moderate)],
        "ME": [.init(archetype: .mountainSkiCorridor, strength: .moderate), .init(archetype: .huntingFishingHeritage, strength: .moderate)],
        "NY": [.init(archetype: .mountainSkiCorridor, strength: .moderate), .init(archetype: .urbanDenseTransit, strength: .high)],
        "PA": [.init(archetype: .mountainSkiCorridor, strength: .moderate)],
        "OH": [.init(archetype: .mountainSkiCorridor, strength: .moderate)],
        "IN": [.init(archetype: .mountainSkiCorridor, strength: .moderate)],
        "WI": [.init(archetype: .mountainSkiCorridor, strength: .moderate), .init(archetype: .lakeBoatingBelt, strength: .high), .init(archetype: .huntingFishingHeritage, strength: .moderate)],
        "MN": [.init(archetype: .mountainSkiCorridor, strength: .moderate), .init(archetype: .lakeBoatingBelt, strength: .high), .init(archetype: .huntingFishingHeritage, strength: .moderate)],
        "MI": [.init(archetype: .mountainSkiCorridor, strength: .moderate), .init(archetype: .lakeBoatingBelt, strength: .high)],
        "WA": [.init(archetype: .mountainSkiCorridor, strength: .moderate), .init(archetype: .urbanDenseTransit, strength: .moderate)],
        "OR": [.init(archetype: .mountainSkiCorridor, strength: .moderate)],
        "NM": [.init(archetype: .mountainSkiCorridor, strength: .moderate)],
        "WV": [.init(archetype: .mountainSkiCorridor, strength: .moderate), .init(archetype: .huntingFishingHeritage, strength: .high)],

        // Lake & Boating Belt (additional states beyond the ski-overlap ones above)
        "TX": [.init(archetype: .lakeBoatingBelt, strength: .moderate), .init(archetype: .ranchWesternHeritage, strength: .high), .init(archetype: .suburbanYouthSportsBelt, strength: .moderate)],
        "FL": [.init(archetype: .lakeBoatingBelt, strength: .moderate), .init(archetype: .coastalBeachClub, strength: .high), .init(archetype: .golfRetirementCorridor, strength: .high)],

        // Coastal & Beach Club
        "HI": [.init(archetype: .coastalBeachClub, strength: .high)],
        "CA": [.init(archetype: .coastalBeachClub, strength: .moderate), .init(archetype: .urbanDenseTransit, strength: .moderate)],
        "NJ": [.init(archetype: .coastalBeachClub, strength: .moderate), .init(archetype: .urbanDenseTransit, strength: .moderate)],
        "NC": [.init(archetype: .coastalBeachClub, strength: .moderate), .init(archetype: .golfRetirementCorridor, strength: .moderate), .init(archetype: .suburbanYouthSportsBelt, strength: .moderate)],
        "SC": [.init(archetype: .coastalBeachClub, strength: .moderate), .init(archetype: .golfRetirementCorridor, strength: .high)],

        // Golf & Retirement Corridor
        "AZ": [.init(archetype: .golfRetirementCorridor, strength: .high), .init(archetype: .suburbanYouthSportsBelt, strength: .moderate)],

        // Urban Dense / Transit
        "DC": [.init(archetype: .urbanDenseTransit, strength: .high)],
        "MA": [.init(archetype: .urbanDenseTransit, strength: .high), .init(archetype: .collegeTown, strength: .moderate)],
        "IL": [.init(archetype: .urbanDenseTransit, strength: .high)],

        // Suburban Youth-Sports Belt
        "GA": [.init(archetype: .suburbanYouthSportsBelt, strength: .moderate)],

        // Ranch & Western Heritage / Hunting & Fishing Heritage
        "OK": [.init(archetype: .ranchWesternHeritage, strength: .high), .init(archetype: .huntingFishingHeritage, strength: .moderate)],
        "AR": [.init(archetype: .huntingFishingHeritage, strength: .high)],
        "MS": [.init(archetype: .huntingFishingHeritage, strength: .high)],
        "TN": [.init(archetype: .huntingFishingHeritage, strength: .moderate)],
        "KY": [.init(archetype: .huntingFishingHeritage, strength: .moderate)],
    ]
}
