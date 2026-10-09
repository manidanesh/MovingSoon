import Foundation

/// Area household counts, never an estimate of this customer's income.
enum AreaIncomeBand: String, Codable, CaseIterable, Identifiable {
    case under35k, from35to50k, from50to75k, from75to100k, from100to150k, from150to200k, over200k
    var id: String { rawValue }
    var title: String {
        switch self {
        case .under35k: return "Under $35,000"
        case .from35to50k: return "$35,000–49,999"
        case .from50to75k: return "$50,000–74,999"
        case .from75to100k: return "$75,000–99,999"
        case .from100to150k: return "$100,000–149,999"
        case .from150to200k: return "$150,000–199,999"
        case .over200k: return "$200,000 or more"
        }
    }
    /// Published ACS B19001 income bins. Each cell belongs to exactly one band.
    var censusCells: ClosedRange<Int> {
        switch self {
        case .under35k: return 2...7
        case .from35to50k: return 8...10
        case .from50to75k: return 11...12
        case .from75to100k: return 13...13
        case .from100to150k: return 14...15
        case .from150to200k: return 16...16
        case .over200k: return 17...17
        }
    }
}

struct AreaIncomeCount: Codable, Equatable {
    let band: AreaIncomeBand
    let households: Double
    /// Root-sum-square approximation of the published count MOEs for grouped cells.
    let marginOfError: Double?
}

struct AreaIncomeDistribution: Codable, Equatable {
    let totalHouseholds: Double
    let totalMarginOfError: Double?
    let counts: [AreaIncomeCount]

    var isComplete: Bool {
        totalHouseholds.isFinite && totalHouseholds > 0
            && counts.count == AreaIncomeBand.allCases.count
            && Set(counts.map(\.band)) == Set(AreaIncomeBand.allCases)
            && counts.allSatisfy { $0.households.isFinite && $0.households >= 0 }
            && abs(counts.reduce(0) { $0 + $1.households } - totalHouseholds) < 0.5
    }

    func share(in band: AreaIncomeBand) -> Double? {
        guard isComplete, let count = counts.first(where: { $0.band == band }) else { return nil }
        return count.households / totalHouseholds
    }

    static let variables = (1...17).flatMap { cell in
        [String(format: "B19001_%03dE", cell), String(format: "B19001_%03dM", cell)]
    }

    static func parse(_ values: [String: String]) -> AreaIncomeDistribution? {
        func value(_ cell: Int, _ suffix: String) -> Double? {
            guard let raw = values[String(format: "B19001_%03d%@", cell, suffix)],
                  let value = Double(raw), value.isFinite, value >= 0 else { return nil }
            return value
        }
        guard let total = value(1, "E"), total > 0 else { return nil }
        var counts: [AreaIncomeCount] = []
        for band in AreaIncomeBand.allCases {
            let estimates = band.censusCells.compactMap { value($0, "E") }
            guard estimates.count == band.censusCells.count else { return nil }
            let errors = band.censusCells.compactMap { value($0, "M") }
            let moe = errors.count == band.censusCells.count ? sqrt(errors.reduce(0) { $0 + $1 * $1 }) : nil
            counts.append(AreaIncomeCount(band: band, households: estimates.reduce(0, +), marginOfError: moe))
        }
        let distribution = AreaIncomeDistribution(totalHouseholds: total, totalMarginOfError: value(1, "M"), counts: counts)
        return distribution.isComplete ? distribution : nil
    }
}
