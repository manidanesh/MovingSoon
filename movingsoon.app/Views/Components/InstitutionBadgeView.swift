// InstitutionBadgeView.swift — Colored circle with institution initials
import SwiftUI

struct InstitutionBadgeView: View {
    let initials: String
    let colorHex: String
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorHex))
            Text(initials)
                .font(.system(size: size * 0.33, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Category Icon (SF Symbol in colored rounded square)

struct CategoryIconView: View {
    let category: TaskCategory
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(categoryColor.opacity(0.2))
            Image(systemName: category.icon)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundColor(categoryColor)
        }
        .frame(width: size, height: size)
    }

    private var categoryColor: Color {
        switch category {
        case .postal:        return Color(hex: "#004B87")
        case .government:    return Color(hex: "#7D3C98")
        case .financial:     return Color(hex: "#117ACA")
        case .utilities:     return Color(hex: "#E67E22")
        case .subscriptions: return Color(hex: "#1ABC9C")
        case .healthcare:    return Color(hex: "#C0392B")
        case .education:     return Color(hex: "#2E86C1")
        case .insurance:     return Color(hex: "#27AE60")
        case .legal:         return Color(hex: "#8E44AD")
        case .employer:      return Color(hex: "#2C3E50")
        case .other:         return Color(hex: "#626567")
        }
    }
}
