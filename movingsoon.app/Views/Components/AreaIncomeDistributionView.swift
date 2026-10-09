import SwiftUI

struct AreaIncomeDistributionView: View {
    let comparison: AreaMarketComparison

    var body: some View {
        if comparison.origin?.incomeDistribution != nil || comparison.destination.incomeDistribution != nil {
            DisclosureGroup("Household incomes across these areas") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share of households in each income bracket. These are area estimates; your household’s income has not been estimated.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text("Annual income")
                            Text("Previous area")
                            Text("New area")
                        }.font(.caption.weight(.semibold))
                        ForEach(AreaIncomeBand.allCases) { band in
                            GridRow {
                                Text(band.title)
                                Text(share(band, in: comparison.origin))
                                Text(share(band, in: comparison.destination))
                            }.font(.caption)
                        }
                    }
                    Text("2020–2024 ACS B19001 · percentages are rounded. Missing values are shown as —.")
                        .font(.caption2).foregroundStyle(Theme.textTertiary)
                }.padding(.top, 12)
            }
        }
    }

    private func share(_ band: AreaIncomeBand, in profile: AreaMarketProfile?) -> String {
        guard let value = profile?.incomeDistribution?.share(in: band) else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }
}
