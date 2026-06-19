// Theme.swift — Design System — Option B: Calm Confidence (Navy + Blue)
import SwiftUI

enum Theme {
    // MARK: - Backgrounds
    static let backgroundPrimary  = Color(hex: "#0A0F1E")   // Deep navy — warm, not pure black
    static let backgroundCard     = Color(hex: "#111827")   // Navy charcoal card surface
    static let backgroundElevated = Color(hex: "#1E2940")   // Elevated navy

    // MARK: - Text
    static let textPrimary   = Color(hex: "#F9FAFB")   // Near white, slightly warm
    static let textSecondary = Color(hex: "#9CA3AF")   // Neutral grey
    static let textTertiary  = Color(hex: "#4B5563")   // Muted

    // MARK: - Dividers
    static let hairline = Color(hex: "#1F2937")

    // MARK: - Primary accent — Electric Blue (calm, trustworthy, actionable)
    static let accentPrimary = Color(hex: "#3B82F6")   // Blue

    // MARK: - Semantic colors
    static let accentSuccess = Color(hex: "#22C55E")   // Green — "done, safe, handled"
    static let accentWarning = Color(hex: "#F59E0B")   // Amber — "due soon"
    static let accentPending = Color(hex: "#F59E0B")   // Amber — pending verification

    // MARK: - Priority
    static let priorityCritical = Color(hex: "#EF4444")   // Red — only truly overdue/critical
    static let priorityHigh     = Color(hex: "#F97316")   // Orange
    static let priorityMedium   = Color(hex: "#3B82F6")   // Blue
    static let priorityLow      = Color(hex: "#6B7280")   // Grey

    // MARK: - USPS Hero
    static let uspsBlue = Color(hex: "#004B87")
    static let uspsRed  = Color(hex: "#DA291C")

    // MARK: - Gradients
    static let heroGradient = LinearGradient(
        colors: [Color(hex: "#004B87"), Color(hex: "#0072CE")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appGradient = LinearGradient(
        colors: [Color(hex: "#0A0F1E"), Color(hex: "#0D1526")],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Blue gradient for cards/buttons
    static let blueGradient = LinearGradient(
        colors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
