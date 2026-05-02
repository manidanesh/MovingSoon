// Theme.swift — Design System
import SwiftUI

enum Theme {
    // MARK: - Backgrounds
    static let backgroundPrimary  = Color.black
    static let backgroundCard     = Color(white: 0.05) // Deepest charcoal, almost black
    static let backgroundElevated = Color(white: 0.08)

    // MARK: - Text
    static let textPrimary   = Color(white: 0.98)
    static let textSecondary = Color(white: 0.65)
    static let textTertiary  = Color(white: 0.40)
    
    // MARK: - Dividers
    static let hairline = Color(white: 0.15)

    // MARK: - Accents
    static let accentPrimary = Color(hex: "#FF6B6B")   // coral
    static let accentSuccess = Color(hex: "#4ECDC4")   // teal
    static let accentPending = Color(hex: "#F5A623")   // amber

    // MARK: - Priority
    static let priorityCritical = Color(hex: "#FF4757")
    static let priorityHigh     = Color(hex: "#FF8C42")
    static let priorityMedium   = Color(hex: "#60A5FA")
    static let priorityLow      = Color(hex: "#6B7280")

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
        colors: [Color(hex: "#0B0E17"), Color(hex: "#111827")],
        startPoint: .top,
        endPoint: .bottom
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
