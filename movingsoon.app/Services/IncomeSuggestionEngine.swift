import Foundation

struct IncomeSuggestionAdjustment {
    let points: Int
    let sourceTitle: String
    let modelVersion: String
}

enum IncomeSuggestionEngine {
    static let featureDefinition = "acs2024.originZCTA.householdIncomeShares.v1"

    /// Only the origin area's distribution informs possible existing enrollment.
    /// Destination prices never erase a confirmed account or a customer's answer.
    static func adjustment(for serviceID: String, origin: AreaMarketProfile?,
                           manifest: IncomePilotManifest = ServiceEvidenceCatalog.bundled,
                           now: Date = Date()) -> IncomeSuggestionAdjustment? {
        guard manifest.isStructurallyValid,
              let origin, origin.zip.count == 5,
              origin.zip.allSatisfy({ $0 >= "0" && $0 <= "9" }),
              origin.vintage == "2020–2024 ACS 5-year estimates",
              now.timeIntervalSince(origin.retrievedAt) >= 0,
              now.timeIntervalSince(origin.retrievedAt) <= 90 * 86400,
              let distribution = origin.incomeDistribution, distribution.isComplete,
              let totalMOE = distribution.totalMarginOfError, totalMOE.isFinite, totalMOE >= 0,
              totalMOE / distribution.totalHouseholds <= 0.5,
              distribution.counts.allSatisfy({ count in
                  guard let moe = count.marginOfError else { return false }
                  return moe.isFinite && moe >= 0 && moe / distribution.totalHouseholds <= 0.5
              }),
              let rule = manifest.rules.first(where: { $0.serviceID == serviceID }),
              rule.reviewedForRelease, rule.featureDefinition == featureDefinition,
              rule.validFrom <= now, rule.validUntil > now,
              rule.validation.modelVersion == rule.modelVersion,
              rule.validation.passesLaunchCriteria,
              let source = manifest.sources.first(where: { $0.id == rule.sourceID }),
              source.kind == .serviceUseSurvey, source.offlineUseApproved,
              Set(rule.coefficients.keys) == Set(AreaIncomeBand.allCases.map(\.rawValue)),
              rule.coefficients.values.allSatisfy({ $0.isFinite && abs($0) <= 1 }) else { return nil }

        let weighted = AreaIncomeBand.allCases.reduce(0.0) {
            $0 + (distribution.share(in: $1) ?? 0) * (rule.coefficients[$1.rawValue] ?? 0)
        }
        let points = max(-4, min(4, Int((weighted * 4).rounded())))
        return IncomeSuggestionAdjustment(points: points, sourceTitle: source.title, modelVersion: rule.modelVersion)
    }
}
