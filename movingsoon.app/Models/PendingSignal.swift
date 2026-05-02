// PendingSignal.swift — On-device queue for anonymous Global Brain signals
import Foundation
import SwiftData

@Model
final class PendingSignal {
    var id: UUID
    var personaBucket: String
    var regionState: String
    var regionCityBucket: String?
    var noisyEmbedding: [Float]   // 384 dims, Laplace noise applied on-device
    var clientTimestampHour: Date // floored to the hour — no minute/second precision
    var schemaVersion: String
    var createdAt: Date
    var emittedAt: Date?

    init(personaBucket: String, regionState: String, regionCityBucket: String?, noisyEmbedding: [Float]) {
        self.id                  = UUID()
        self.personaBucket       = personaBucket
        self.regionState         = regionState
        self.regionCityBucket    = regionCityBucket
        self.noisyEmbedding      = noisyEmbedding
        self.clientTimestampHour = Self.floorToHour(Date())
        self.schemaVersion       = "1.0"
        self.createdAt           = Date()
        self.emittedAt           = nil
    }

    var isPending: Bool { emittedAt == nil }

    private static func floorToHour(_ date: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
        comps.minute = 0; comps.second = 0
        return Calendar.current.date(from: comps) ?? date
    }
}
