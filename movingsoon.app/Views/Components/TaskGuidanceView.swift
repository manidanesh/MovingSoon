import SwiftUI

extension ChecklistTask {
    @MainActor var actionURL: URL? {
        guard let move else { return deepLinkURL }
        return CatalogGuidance.actionURL(for: self, move: move)
    }
}

struct TaskGuidanceView: View {
    let task: ChecklistTask
    let move: Move
    var body: some View {
        let guidance = CatalogGuidance.guidance(for: task, move: move)
        VStack(alignment: .leading, spacing: 12) {
            Text("How to handle this").font(.headline)
            Text(guidance.eligibility).font(.subheadline)
            if !guidance.preparation.isEmpty {
                Text("Have ready").font(.subheadline.weight(.semibold))
                ForEach(Array(guidance.preparation.enumerated()), id: \.offset) { _, item in
                    Text("• \(item)").font(.subheadline)
                }
            }
            ForEach(Array(guidance.steps.enumerated()), id: \.offset) { index, step in
                Text("\(index + 1). \(step)").font(.subheadline)
            }
            Text(guidance.timing).font(.footnote)
            if let url = guidance.sourceURL { Link(guidance.sourceTitle, destination: url).font(.footnote) }
            Text("\(guidance.sourceNote) · Reviewed \(guidance.reviewedOn)")
                .font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 14))
    }
}
