import Foundation

enum IncomeEvidenceKind: String, Codable {
    case areaDemographics, categorySpending, modeledMarketEstimate, serviceUseSurvey
}

struct IncomeEvidenceSource: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let kind: IncomeEvidenceKind
    let population: String
    let period: String
    let offlineUseApproved: Bool
    let limitations: String
}

struct ServicePilotEntry: Codable, Identifiable {
    let id: String // Canonical catalog ID, never a second service registry.
    let question: String
    let sourceIDs: [String]
    let researchCategory: String
    let mappingLimit: String
}

struct IncomeValidationStratum: Codable {
    let id: String
    let households: Int
    let usefulLiftLower95: Double
    let irrelevantIncreaseUpper95: Double
}

struct IncomeValidationReport: Codable {
    let modelVersion: String
    let independentHoldout: Bool
    let synthetic: Bool
    let households: Int
    let regionCount: Int
    let excludedHouseholds: Int
    let usefulLiftLower95: Double
    let irrelevantIncreaseUpper95: Double
    let incomeStrata: [IncomeValidationStratum]
    let regionStrata: [IncomeValidationStratum]
    let reportSHA256: String

    /// Conservative launch criteria, not a substitute for study design review.
    var passesLaunchCriteria: Bool {
        guard independentHoldout, !synthetic, households >= 200, regionCount >= 3, excludedHouseholds == 0,
              usefulLiftLower95.isFinite, usefulLiftLower95 > 0,
              irrelevantIncreaseUpper95.isFinite, irrelevantIncreaseUpper95 <= 0,
              reportSHA256.count == 64, reportSHA256.allSatisfy(\.isHexDigit),
              incomeStrata.count == AreaIncomeBand.allCases.count,
              Set(incomeStrata.map(\.id)) == Set(AreaIncomeBand.allCases.map(\.rawValue)),
              regionStrata.count == regionCount,
              Set(regionStrata.map(\.id)).count == regionCount,
              regionStrata.allSatisfy({ !$0.id.isEmpty }),
              incomeStrata.reduce(0, { $0 + $1.households }) == households,
              regionStrata.reduce(0, { $0 + $1.households }) == households else { return false }
        return (incomeStrata + regionStrata).allSatisfy {
            $0.households >= 20 && $0.usefulLiftLower95.isFinite && $0.usefulLiftLower95 >= 0
                && $0.irrelevantIncreaseUpper95.isFinite && $0.irrelevantIncreaseUpper95 <= 0
        }
    }
}

/// A future validated association can change question order by at most four points.
/// No rules ship in v1: public income/spending tables contain no service-use labels.
struct IncomeRankingRule: Codable {
    let serviceID: String
    let sourceID: String
    let modelVersion: String
    let featureDefinition: String
    let reviewedForRelease: Bool
    let validFrom: Date
    let validUntil: Date
    let coefficients: [String: Double]
    let validation: IncomeValidationReport
}

struct IncomePilotManifest: Codable {
    let schemaVersion: Int
    let version: String
    let sources: [IncomeEvidenceSource]
    let services: [ServicePilotEntry]
    let rules: [IncomeRankingRule]

    var isStructurallyValid: Bool {
        schemaVersion == 1 && !version.isEmpty
            && Set(services.map(\.id)).count == services.count
            && Set(sources.map(\.id)).count == sources.count
            && Set(rules.map(\.serviceID)).count == rules.count
            && services.allSatisfy { entry in
                !entry.question.isEmpty && !entry.sourceIDs.isEmpty
                    && entry.sourceIDs.allSatisfy { id in sources.contains { $0.id == id } }
            }
            && rules.allSatisfy { rule in
                services.contains { $0.id == rule.serviceID && $0.sourceIDs.contains(rule.sourceID) }
            }
    }
}

enum ServiceEvidenceCatalog {
    static let bundled: IncomePilotManifest = {
        guard let url = Bundle.main.url(forResource: "IncomePilot", withExtension: "json"),
              let data = try? Data(contentsOf: url), let manifest = decode(data) else {
            return IncomePilotManifest(schemaVersion: 1, version: "unavailable", sources: [], services: [], rules: [])
        }
        return manifest
    }()

    static func decode(_ data: Data) -> IncomePilotManifest? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(IncomePilotManifest.self, from: data),
              manifest.isStructurallyValid else { return nil }
        return manifest
    }
}
