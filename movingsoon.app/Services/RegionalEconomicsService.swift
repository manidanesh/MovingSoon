// RegionalEconomicsService.swift — On-device state-level income/home-value snapshot (no network call)
//
// Snapshot vintage: median household income from Census ACS via FRED (2024 estimate,
// series MEHOINUS{state}A646N), median home value from Zillow ZHVI state series
// (July 2026). Both are bundled static data, matching ZipBucketService's offline
// pattern — refreshing this table means re-pulling the same two public sources and
// regenerating the dictionary below, not adding a runtime network dependency.
//
// Census/Zillow are US-only — there is no snapshot for Canadian province buckets
// (e.g. "ON", "BC"), so `compare` returns nil whenever either side of a move maps to
// a non-US bucket. Canada would need a separate source (e.g. Statistics Canada /
// CREA) before that gap could close.
import Foundation

enum RegionalEconomicsService {

    struct Snapshot {
        let medianHouseholdIncome: Int   // USD/year
        let medianHomeValue: Int         // USD, Zillow ZHVI
    }

    /// How the destination compares to the origin on cost, not a judgment about
    /// whether the move itself is good or bad — a cheaper, bigger home is a
    /// "cost decrease" here even if it's a lifestyle upgrade.
    enum CostDirection: Equatable {
        case costIncrease
        case costDecrease
        case comparable
    }

    struct Comparison {
        let incomeDeltaPercent: Double
        let homeValueDeltaPercent: Double
        let direction: CostDirection
    }

    /// Home-value delta beyond which a move is no longer considered "comparable."
    private static let comparableThresholdPercent = 10.0

    // MARK: - Snapshot data

    private static let snapshots: [String: Snapshot] = [
        "AK": Snapshot(medianHouseholdIncome: 91260, medianHomeValue: 402190),
        "AL": Snapshot(medianHouseholdIncome: 65560, medianHomeValue: 241009),
        "AR": Snapshot(medianHouseholdIncome: 64840, medianHomeValue: 225822),
        "AZ": Snapshot(medianHouseholdIncome: 84700, medianHomeValue: 421381),
        "CA": Snapshot(medianHouseholdIncome: 100600, medianHomeValue: 773735),
        "CO": Snapshot(medianHouseholdIncome: 106500, medianHomeValue: 538932),
        "CT": Snapshot(medianHouseholdIncome: 99240, medianHomeValue: 453319),
        "DC": Snapshot(medianHouseholdIncome: 104800, medianHomeValue: 577041),
        "DE": Snapshot(medianHouseholdIncome: 85860, medianHomeValue: 410192),
        "FL": Snapshot(medianHouseholdIncome: 75630, medianHomeValue: 378167),
        "GA": Snapshot(medianHouseholdIncome: 81210, medianHomeValue: 334119),
        "HI": Snapshot(medianHouseholdIncome: 98240, medianHomeValue: 833877),
        "IA": Snapshot(medianHouseholdIncome: 85480, medianHomeValue: 240435),
        "ID": Snapshot(medianHouseholdIncome: 81650, medianHomeValue: 481825),
        "IL": Snapshot(medianHouseholdIncome: 84210, medianHomeValue: 299900),
        "IN": Snapshot(medianHouseholdIncome: 76710, medianHomeValue: 260808),
        "KS": Snapshot(medianHouseholdIncome: 87690, medianHomeValue: 250918),
        "KY": Snapshot(medianHouseholdIncome: 64790, medianHomeValue: 234510),
        "LA": Snapshot(medianHouseholdIncome: 60740, medianHomeValue: 217092),
        "MA": Snapshot(medianHouseholdIncome: 113900, medianHomeValue: 669053),
        "MD": Snapshot(medianHouseholdIncome: 109700, medianHomeValue: 433112),
        "ME": Snapshot(medianHouseholdIncome: 90730, medianHomeValue: 421966),
        "MI": Snapshot(medianHouseholdIncome: 79460, medianHomeValue: 269576),
        "MN": Snapshot(medianHouseholdIncome: 92350, medianHomeValue: 356066),
        "MO": Snapshot(medianHouseholdIncome: 78390, medianHomeValue: 268420),
        "MS": Snapshot(medianHouseholdIncome: 55980, medianHomeValue: 196333),
        "MT": Snapshot(medianHouseholdIncome: 81920, medianHomeValue: 475191),
        "NC": Snapshot(medianHouseholdIncome: 67220, medianHomeValue: 338359),
        "ND": Snapshot(medianHouseholdIncome: 88080, medianHomeValue: 293741),
        "NE": Snapshot(medianHouseholdIncome: 86140, medianHomeValue: 282767),
        "NH": Snapshot(medianHouseholdIncome: 111800, medianHomeValue: 521177),
        "NJ": Snapshot(medianHouseholdIncome: 103500, medianHomeValue: 584072),
        "NM": Snapshot(medianHouseholdIncome: 64140, medianHomeValue: 320106),
        "NV": Snapshot(medianHouseholdIncome: 80590, medianHomeValue: 447473),
        "NY": Snapshot(medianHouseholdIncome: 86830, medianHomeValue: 527312),
        "OH": Snapshot(medianHouseholdIncome: 80520, medianHomeValue: 249941),
        "OK": Snapshot(medianHouseholdIncome: 65310, medianHomeValue: 223612),
        "OR": Snapshot(medianHouseholdIncome: 89700, medianHomeValue: 502156),
        "PA": Snapshot(medianHouseholdIncome: 80060, medianHomeValue: 290552),
        "RI": Snapshot(medianHouseholdIncome: 92290, medianHomeValue: 515289),
        "SC": Snapshot(medianHouseholdIncome: 76780, medianHomeValue: 307777),
        "SD": Snapshot(medianHouseholdIncome: 79850, medianHomeValue: 324891),
        "TN": Snapshot(medianHouseholdIncome: 75860, medianHomeValue: 336508),
        "TX": Snapshot(medianHouseholdIncome: 81490, medianHomeValue: 301806),
        "UT": Snapshot(medianHouseholdIncome: 104000, medianHomeValue: 539949),
        "VA": Snapshot(medianHouseholdIncome: 97720, medianHomeValue: 418375),
        "VT": Snapshot(medianHouseholdIncome: 85260, medianHomeValue: 405980),
        "WA": Snapshot(medianHouseholdIncome: 97500, medianHomeValue: 601545),
        "WI": Snapshot(medianHouseholdIncome: 82560, medianHomeValue: 343798),
        "WV": Snapshot(medianHouseholdIncome: 63150, medianHomeValue: 178702),
        "WY": Snapshot(medianHouseholdIncome: 78680, medianHomeValue: 371685),
        "US": Snapshot(medianHouseholdIncome: 83730, medianHomeValue: 390050),  // national fallback — unweighted mean across states
    ]

    static func snapshot(forStateBucket bucket: String) -> Snapshot? {
        snapshots[bucket]
    }

    /// Compares origin vs. destination state buckets on income and home value.
    /// Returns nil when either bucket has no snapshot (Canadian provinces, or no
    /// origin was ever captured).
    static func compare(originStateBucket: String?, destinationStateBucket: String) -> Comparison? {
        guard let originStateBucket,
              let origin = snapshots[originStateBucket],
              let destination = snapshots[destinationStateBucket] else { return nil }

        let incomeDelta = percentDelta(from: origin.medianHouseholdIncome, to: destination.medianHouseholdIncome)
        let homeValueDelta = percentDelta(from: origin.medianHomeValue, to: destination.medianHomeValue)

        let direction: CostDirection
        if homeValueDelta > comparableThresholdPercent {
            direction = .costIncrease
        } else if homeValueDelta < -comparableThresholdPercent {
            direction = .costDecrease
        } else {
            direction = .comparable
        }

        return Comparison(incomeDeltaPercent: incomeDelta, homeValueDeltaPercent: homeValueDelta, direction: direction)
    }

    private static func percentDelta(from: Int, to: Int) -> Double {
        guard from != 0 else { return 0 }
        return (Double(to) - Double(from)) / Double(from) * 100
    }
}
