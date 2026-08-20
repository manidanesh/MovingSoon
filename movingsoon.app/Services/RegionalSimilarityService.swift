// RegionalSimilarityService.swift — WS3 of the intelligence-rework scope.
//
// Honesty note (architecture review §14): this is NOT a learned embedding. There is
// no labeled dataset anywhere in this app saying "these two regions are similar for
// movers." What follows is a hand-engineered feature vector — the existing
// RegionalArchetypeService match strengths plus RegionalEconomicsService's income and
// home-value data, encoded as continuous dimensions — scored by cosine similarity.
// It's a real improvement over discrete bucket-matching (continuous beats discrete,
// and it stops flattening e.g. all of California into one score), but it's still
// hand-curation, just smoother. A genuinely learned version depends on real signal
// from SignalEmitter/PendingSignal existing first — see the review for why that
// sequencing matters.
//
// Deliberately additive: does not modify RegionalArchetypeService's table or
// MoveImpactEngine's candidate generation, so every test written against either
// keeps passing unchanged. This adds a new capability rather than replacing an
// existing one.
import Foundation

enum RegionalSimilarityService {

    /// One dimension per RegionalArchetype (0.0 absent, 0.5 moderate, 1.0 high — from
    /// the existing hand-curated table) plus normalized median household income and
    /// median home value from RegionalEconomicsService.
    static func featureVector(forStateBucket bucket: String) -> [Double] {
        let matches = RegionalArchetypeService.matches(forStateBucket: bucket)
        var vector = RegionalArchetype.allCases.map { archetype -> Double in
            guard let match = matches.first(where: { $0.archetype == archetype }) else { return 0.0 }
            return match.strength == .high ? 1.0 : 0.5
        }
        if let snapshot = RegionalEconomicsService.snapshot(forStateBucket: bucket) {
            vector.append(normalized(snapshot.medianHouseholdIncome, min: 55_000, max: 115_000))
            vector.append(normalized(snapshot.medianHomeValue, min: 175_000, max: 835_000))
        } else {
            vector.append(0)
            vector.append(0)
        }
        return vector
    }

    /// Cosine similarity between two state buckets' feature vectors. 1.0 means an
    /// identical regional profile on every dimension tracked here; 0.0 means no shared
    /// signal (or one side has no data at all — e.g. a Canadian province bucket).
    static func similarity(between stateA: String, and stateB: String) -> Double {
        let a = featureVector(forStateBucket: stateA)
        let b = featureVector(forStateBucket: stateB)
        let dot = zip(a, b).reduce(0.0) { $0 + $1.0 * $1.1 }
        let magnitudeA = (a.reduce(0.0) { $0 + $1 * $1 }).squareRoot()
        let magnitudeB = (b.reduce(0.0) { $0 + $1 * $1 }).squareRoot()
        guard magnitudeA > 0, magnitudeB > 0 else { return 0 }
        return dot / (magnitudeA * magnitudeB)
    }

    /// Rough min-max scaling against the observed range in RegionalEconomicsService's
    /// snapshot table — not a statistically derived scale, just enough to put income
    /// and home value on a comparable 0...1 footing with the archetype dimensions above.
    private static func normalized(_ value: Int, min: Double, max: Double) -> Double {
        Swift.min(Swift.max((Double(value) - min) / (max - min), 0), 1)
    }
}
