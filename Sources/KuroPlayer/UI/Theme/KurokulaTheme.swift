import SwiftUI

struct KurokulaTheme {
    static let background = Color(hex: "#131515")
    static let foreground = Color(hex: "#dfcfc2")
    static let accent = Color(hex: "#791c1c")
    static let secondary = Color(hex: "#fff600")
    static let success = Color(hex: "#aeffa4")
    static let error = Color(hex: "#c35951")
    static let gray = Color(hex: "#505151")
    static let white = Color(hex: "#feffff")
    
    static let sidebar = Color(hex: "#1a1c1c")
    static let playerBar = Color(hex: "#1e2020")
    static let cardBackground = Color(hex: "#1e2020")
    static let hoverBackground = Color(hex: "#252828")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
