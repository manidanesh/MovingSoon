import Foundation

enum MoveFitDirection {
    case destinationHigher
    case destinationLower
    case noClearDifference
}

struct MoveFitHousingMeasure {
    let title: String
    let unit: String
    let originValue: Double
    let destinationValue: Double
    let direction: MoveFitDirection
    let differencePercent: Int
}

/// Explainable comparison rules. A direction is shown only when the estimates'
/// difference exceeds their combined 90% margins of error.
enum MoveFitEngine {
    static func housingMeasure(comparison: AreaMarketComparison, flags: Set<LifestyleFlag>) -> MoveFitHousingMeasure? {
        let origin = comparison.origin
        let destination = comparison.destination
        let rents = flags.contains(.isRenting)
        let owns = flags.contains(.isOwning)
        guard rents != owns else { return nil }
        let metric: (String, String, Double?, Double?, Double?, Double?)
        if rents {
            metric = ("Median gross rent", "monthly", origin?.medianGrossRent, destination.medianGrossRent,
                      origin?.medianGrossRentMOE, destination.medianGrossRentMOE)
        } else {
            metric = ("Median monthly owner costs", "monthly", origin?.medianMonthlyOwnerCosts, destination.medianMonthlyOwnerCosts,
                      origin?.medianMonthlyOwnerCostsMOE, destination.medianMonthlyOwnerCostsMOE)
        }
        guard let originValue = metric.2, let destinationValue = metric.3 else { return nil }
        let direction: MoveFitDirection
        if let originMOE = metric.4, let destinationMOE = metric.5 {
            let combinedMOE = hypot(originMOE, destinationMOE)
            if abs(destinationValue - originValue) <= combinedMOE {
                direction = .noClearDifference
            } else {
                direction = destinationValue > originValue ? .destinationHigher : .destinationLower
            }
        } else {
            direction = .noClearDifference
        }
        let percent = originValue == 0 ? 0 : Int((abs(destinationValue - originValue) / originValue * 100).rounded())
        return MoveFitHousingMeasure(title: metric.0, unit: metric.1, originValue: originValue,
                                     destinationValue: destinationValue, direction: direction,
                                     differencePercent: percent)
    }

    static func homeValueMeasure(comparison: AreaMarketComparison) -> MoveFitHousingMeasure? {
        guard let originValue = comparison.origin?.medianHomeValue,
              let destinationValue = comparison.destination.medianHomeValue else { return nil }
        let direction: MoveFitDirection
        if let originMOE = comparison.origin?.medianHomeValueMOE,
           let destinationMOE = comparison.destination.medianHomeValueMOE,
           abs(destinationValue - originValue) > hypot(originMOE, destinationMOE) {
            direction = destinationValue > originValue ? .destinationHigher : .destinationLower
        } else {
            direction = .noClearDifference
        }
        let percent = originValue == 0 ? 0 : Int((abs(destinationValue - originValue) / originValue * 100).rounded())
        return MoveFitHousingMeasure(title: "Median home value", unit: "area median",
                                     originValue: originValue, destinationValue: destinationValue,
                                     direction: direction, differencePercent: percent)
    }
}
