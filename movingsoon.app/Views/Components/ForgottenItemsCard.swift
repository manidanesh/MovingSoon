import SwiftUI
import SwiftData

struct ForgottenItemsCard: View {
    let move: Move
    let area: AreaMarketComparison?
    let onReview: () -> Void
    let onChanged: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Anything you may have missed?")
                .font(.headline).foregroundStyle(Theme.textPrimary)
            Text("\(move.reviewedFamilies.count) of \(ReviewFamily.allCases.count) categories reviewed · \(move.completedCount) of \(move.totalCount) tasks done")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            ForEach(ServiceDiscoveryEngine.spotlight(for: move, area: area)) { suggestion in
                ServiceSuggestionRow(suggestion: suggestion, onAdd: {
                    MoveChecklistService.confirm(suggestion.item, for: move, in: modelContext)
                    onChanged()
                }, onResponse: { decision in
                    move.respond(to: suggestion.id, with: decision)
                    modelContext.saveOrLog()
                })
            }
            Button("Review categories or add a service", action: onReview)
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentPrimary)
            Text("Add a suggestion only if it applies to you. You can review the full catalog any time.")
                .font(.caption).foregroundStyle(Theme.textTertiary)
        }
        .padding(18)
        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ServiceSuggestionRow: View {
    let suggestion: ServiceSuggestion
    let onAdd: () -> Void
    let onResponse: (ServiceDecision) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(suggestion.item.emoji) \(suggestion.item.title)")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            Text(suggestion.reason).font(.caption).foregroundStyle(Theme.textSecondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { actions }
                VStack(alignment: .leading, spacing: 12) { actions }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var actions: some View {
        Button("Add to my list", action: onAdd).foregroundStyle(Theme.accentPrimary)
        Button("Doesn't apply") { onResponse(.notApplicable) }.foregroundStyle(Theme.textSecondary)
        Button("Not sure") { onResponse(.unsure) }.foregroundStyle(Theme.textSecondary)
    }
}
