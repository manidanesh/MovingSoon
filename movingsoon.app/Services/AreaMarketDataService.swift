import Foundation
import OSLog

/// Public Census area estimates. These describe a ZIP Code Tabulation Area, not an
/// individual household. Cached locally by ZIP and ACS vintage for offline display.
struct AreaMarketProfile: Codable, Equatable {
    let zip: String
    let medianHouseholdIncome: Double
    let medianHouseholdIncomeMOE: Double?
    let averageHouseholdSize: Double
    let averageHouseholdSizeMOE: Double?
    let familyHouseholdsWithThreeOrMorePercent: Double?
    let medianGrossRent: Double?
    let medianGrossRentMOE: Double?
    let medianMonthlyOwnerCosts: Double?
    let medianMonthlyOwnerCostsMOE: Double?
    let medianHomeValue: Double?
    let medianHomeValueMOE: Double?
    let vintage: String
    let retrievedAt: Date
    var incomeDistribution: AreaIncomeDistribution? = nil
}

struct AreaMarketComparison: Equatable {
    let origin: AreaMarketProfile?
    let destination: AreaMarketProfile
}

enum AreaMarketDataService {
    private static let logger = Logger(subsystem: "app.movingsoon", category: "AreaMarketData")
    private static let year = "2024"
    private static let vintage = "2020–2024 ACS 5-year estimates"
    private static let cachePrefix = "area-market-2024-v2-"
    static let coreVariables = [
        "B19013_001E", "B19013_001M", "B25010_001E", "B25010_001M",
        "B11016_002E", "B11016_004E", "B11016_005E", "B11016_006E", "B11016_007E", "B11016_008E",
        "B25064_001E", "B25064_001M", "B25088_001E", "B25088_001M",
        "B25077_001E", "B25077_001M"
    ]
    // Exactly 50 requested variables: Census limits the get parameter to 50.
    static let variables = coreVariables + AreaIncomeDistribution.variables

    /// Keep the developer key in a local, git-ignored app resource rather than
    /// in Swift source. It is still extractable from a distributed app bundle.
    private static var apiKey: String? {
        if let value = ProcessInfo.processInfo.environment["CENSUS_API_KEY"], !value.isEmpty {
            return value
        }
        guard let url = Bundle.main.url(forResource: "CensusAPIKey", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String],
              let value = plist["CensusAPIKey"], !value.isEmpty else { return nil }
        return value
    }

    static func profile(for zip: String, refresh: Bool = false) async -> AreaMarketProfile? {
        let normalized = zip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 5, normalized.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
        if !refresh, let cached = cachedProfile(for: normalized, allowLegacy: false),
           Date().timeIntervalSince(cached.retrievedAt) < 30 * 86400 { return cached }
        guard let apiKey else {
            logger.error("Census area lookup skipped because no API key is configured.")
            return cachedProfile(for: normalized)
        }

        var components = URLComponents(string: "https://api.census.gov/data/\(year)/acs/acs5")
        components?.queryItems = [
            URLQueryItem(name: "get", value: variables.joined(separator: ",")),
            URLQueryItem(name: "for", value: "zip code tabulation area:\(normalized)"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components?.url else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            guard httpResponse?.statusCode == 200 else {
                logger.error("Census area lookup returned HTTP status \(httpResponse?.statusCode ?? -1).")
                return cachedProfile(for: normalized)
            }
            guard let profile = parseResponse(data, zip: normalized) else {
                logger.error("Census area lookup returned incomplete or unexpected data.")
                return cachedProfile(for: normalized)
            }
            guard !Task.isCancelled else { return nil }
            cache(profile)
            return profile
        } catch {
            // Retain a previously fetched snapshot if a user-triggered refresh fails.
            let nsError = error as NSError
            logger.error("Census area lookup failed with \(nsError.domain, privacy: .public) code \(nsError.code).")
            return cachedProfile(for: normalized)
        }
    }

    /// Nulls and Census suppression sentinels remain missing; a partial sum must
    /// never be presented as a complete family-size estimate.
    static func parseResponse(_ data: Data, zip: String, retrievedAt: Date = Date()) -> AreaMarketProfile? {
        guard let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[Any]],
              rows.count == 2,
              let header = rows.first as? [String], let row = rows.last,
              row.count == header.count, Set(header).count == header.count,
              Set(coreVariables).isSubset(of: Set(header)) else { return nil }
        var values: [String: String] = [:]
        for (key, value) in Swift.zip(header, row) { values[key] = value as? String }
        guard values["zip code tabulation area"] == zip else { return nil }
        guard let income = number(values["B19013_001E"]),
              let householdSize = number(values["B25010_001E"]), householdSize > 0 else { return nil }
        let totalFamilies = number(values["B11016_002E"])
        let familyCounts = ["B11016_004E", "B11016_005E", "B11016_006E", "B11016_007E", "B11016_008E"]
            .compactMap { number(values[$0]) }
        var familyShare: Double?
        if let totalFamilies, totalFamilies > 0, familyCounts.count == 5 {
            let sum = familyCounts.reduce(0, +)
            if sum <= totalFamilies { familyShare = sum / totalFamilies * 100 }
        }
        return AreaMarketProfile(
            zip: zip,
            medianHouseholdIncome: income,
            medianHouseholdIncomeMOE: number(values["B19013_001M"]),
            averageHouseholdSize: householdSize,
            averageHouseholdSizeMOE: number(values["B25010_001M"]),
            familyHouseholdsWithThreeOrMorePercent: familyShare,
            medianGrossRent: number(values["B25064_001E"]),
            medianGrossRentMOE: number(values["B25064_001M"]),
            medianMonthlyOwnerCosts: number(values["B25088_001E"]),
            medianMonthlyOwnerCostsMOE: number(values["B25088_001M"]),
            medianHomeValue: number(values["B25077_001E"]),
            medianHomeValueMOE: number(values["B25077_001M"]),
            vintage: vintage,
            retrievedAt: retrievedAt,
            incomeDistribution: AreaIncomeDistribution.parse(values))
    }

    private static func number(_ raw: String?) -> Double? {
        guard let raw, let value = Double(raw), value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func cacheKey(_ zip: String) -> String { cachePrefix + zip }

    private static func cachedProfile(for zip: String, allowLegacy: Bool = true) -> AreaMarketProfile? {
        let keys = [cacheKey(zip)] + (allowLegacy ? ["area-market-2024-v1-" + zip] : [])
        for key in keys {
            if let data = UserDefaults.standard.data(forKey: key),
               let profile = try? JSONDecoder().decode(AreaMarketProfile.self, from: data), profile.zip == zip {
                return profile
            }
        }
        return nil
    }

    private static func cache(_ profile: AreaMarketProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(profile.zip))
    }
}
