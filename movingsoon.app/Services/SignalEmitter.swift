// SignalEmitter.swift — WS1 of the intelligence-rework scope: the first real writer
// into PendingSignal, which has existed since day one but never had an emitter.
//
// Honesty note on `noisyEmbedding`: there is no trained embedding model anywhere in
// this app (see the architecture review, §14). What this produces is a deterministic
// feature-hash of (flag, archetype, accepted) — the "hashing trick," a standard,
// legitimate technique for turning a categorical signal into a fixed-size vector
// without a trained embedding table — with real Laplace noise applied on top. It is
// a defensible placeholder for the real thing, not the real thing. If a genuinely
// learned embedding space is ever built (see the review's §14 sequencing), this
// function is what gets replaced, not PendingSignal's schema.
import Foundation
import SwiftData

enum SignalEmitter {

    private static let embeddingDimensions = 384
    /// Laplace scale — larger means more noise, stronger privacy, less useful signal.
    /// Unreviewed placeholder pending the real epsilon-budget analysis the architecture
    /// review's §16 says must happen before any transmission path is ever built.
    private static let laplaceScale = 0.5

    /// Records one accept/reject event for a MoveImpactEngine suggestion. Fire-and-forget:
    /// inserts a PendingSignal and returns, no transmission (isPending stays true — see
    /// the rework scope doc's WS1 acceptance criteria).
    static func emit(item: MoveImpactItem, accepted: Bool, move: Move, into context: ModelContext) {
        let signal = PendingSignal(
            personaBucket: move.personaKey.rawValue,
            regionState: move.destinationStateBucket,
            regionCityBucket: move.destinationCityBucket,
            noisyEmbedding: noisyEmbedding(flag: item.flag, archetype: item.archetype, accepted: accepted)
        )
        context.insert(signal)
    }

    // MARK: - Feature hash + Laplace noise

    private static func noisyEmbedding(flag: LifestyleFlag, archetype: RegionalArchetype, accepted: Bool) -> [Float] {
        let seed = "\(flag.rawValue)|\(archetype.rawValue)|\(accepted)"
        return deterministicVector(seed: seed).map { $0 + laplaceNoise(scale: laplaceScale) }
    }

    /// Same seed always produces the same vector; different seeds spread across
    /// roughly [-1, 1] with no meaningful correlation between unrelated seeds — a
    /// splitmix64-based scatter, not a random vector, so it's reproducible across runs.
    private static func deterministicVector(seed: String) -> [Float] {
        var state = fnv1aHash(seed)
        var vector = [Float](repeating: 0, count: embeddingDimensions)
        for i in 0..<embeddingDimensions {
            state = splitmix64(state)
            vector[i] = Float(Int64(state % 2001) - 1000) / 1000.0
        }
        return vector
    }

    private static func fnv1aHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    private static func splitmix64(_ seed: UInt64) -> UInt64 {
        var z = seed &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Inverse-CDF sampling from Laplace(0, scale).
    private static func laplaceNoise(scale: Double) -> Float {
        let u = Double.random(in: -0.499999...0.499999) // avoid log(0) at the boundary
        let sign: Double = u < 0 ? -1 : 1
        return Float(sign * scale * log(1 - 2 * abs(u)))
    }
}
