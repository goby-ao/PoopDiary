import SwiftUI

extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned.removeAll { $0 == "#" }

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let alpha: Double
        let red: Double
        let green: Double
        let blue: Double

        if cleaned.count == 8 {
            alpha = Double((value >> 24) & 0xFF) / 255.0
            red = Double((value >> 16) & 0xFF) / 255.0
            green = Double((value >> 8) & 0xFF) / 255.0
            blue = Double(value & 0xFF) / 255.0
        } else {
            alpha = 1.0
            red = Double((value >> 16) & 0xFF) / 255.0
            green = Double((value >> 8) & 0xFF) / 255.0
            blue = Double(value & 0xFF) / 255.0
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static let poopPrimary = Color(hex: "#86C166")
    static let poopAccent = Color(hex: "#58A83F")
    static let poopLightGreen = Color(hex: "#C8E6B0")
    static let poopMediumGreen = Color(hex: "#9BD17A")
    static let poopDeepGreen = Color(hex: "#5AAA3A")
    static let poopBrown = Color(hex: "#8B5A2B")
    static let poopBrownLight = Color(hex: "#B47A3C")
    static let poopCream = Color(hex: "#FFF7E8")

    static func heatmapColor(for record: PoopRecord?, colorScheme: ColorScheme) -> Color {
        guard let record, record.didPoop else {
            return colorScheme == .dark ? .white.opacity(0.16) : .gray.opacity(0.22)
        }

        switch record.amount {
        case .none:
            return colorScheme == .dark ? .white.opacity(0.16) : .gray.opacity(0.22)
        case .small:
            return .poopLightGreen
        case .normal:
            return .poopMediumGreen
        case .large:
            return .poopDeepGreen
        }
    }
}
