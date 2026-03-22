import SwiftUI

// MARK: - Theme Definition

enum AppTheme: String, CaseIterable, Identifiable {
    case carbon
    case sunset
    case forest
    case arctic
    case neon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .carbon: return "Carbon"
        case .sunset:   return "Sunset"
        case .forest:   return "Forest"
        case .arctic:   return "Arctic"
        case .neon:     return "Neon"
        }
    }

    var icon: String {
        switch self {
        case .carbon: return "circle.fill"
        case .sunset:   return "sun.horizon.fill"
        case .forest:   return "leaf.fill"
        case .arctic:   return "snowflake"
        case .neon:     return "bolt.fill"
        }
    }

    var primaryColor: Color {
        switch self {
        case .carbon: return Color.white
        case .sunset:   return Color(red: 0.95, green: 0.45, blue: 0.30)
        case .forest:   return Color(red: 0.20, green: 0.70, blue: 0.40)
        case .arctic:   return Color(red: 0.55, green: 0.80, blue: 0.95)
        case .neon:     return Color(red: 0.95, green: 0.20, blue: 0.65)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .carbon: return Color.gray
        case .sunset:   return Color(red: 1.00, green: 0.70, blue: 0.35)
        case .forest:   return Color(red: 0.55, green: 0.85, blue: 0.55)
        case .arctic:   return Color(red: 0.75, green: 0.90, blue: 1.00)
        case .neon:     return Color(red: 0.60, green: 0.20, blue: 1.00)
        }
    }

    var backgroundColor: Color {
        switch self {
        case .carbon: return Color.black
        case .sunset:   return Color(red: 0.12, green: 0.06, blue: 0.06)
        case .forest:   return Color(red: 0.04, green: 0.10, blue: 0.06)
        case .arctic:   return Color(red: 0.08, green: 0.10, blue: 0.14)
        case .neon:     return Color(red: 0.04, green: 0.02, blue: 0.08)
        }
    }

    var cardBackground: Color {
        switch self {
        case .carbon: return Color(red: 0.05, green: 0.05, blue: 0.05)
        case .sunset:   return Color(red: 0.20, green: 0.10, blue: 0.08)
        case .forest:   return Color(red: 0.08, green: 0.18, blue: 0.10)
        case .arctic:   return Color(red: 0.14, green: 0.18, blue: 0.24)
        case .neon:     return Color(red: 0.10, green: 0.05, blue: 0.18)
        }
    }

    var textColor: Color {
        switch self {
        case .carbon: return Color(red: 0.95, green: 0.95, blue: 0.95)
        case .sunset:   return Color(red: 1.00, green: 0.95, blue: 0.88)
        case .forest:   return Color(red: 0.92, green: 0.96, blue: 0.88)
        case .arctic:   return Color(red: 0.90, green: 0.94, blue: 0.98)
        case .neon:     return Color(red: 0.95, green: 0.90, blue: 1.00)
        }
    }

    var subtextColor: Color {
        textColor.opacity(0.6)
    }

    var accentColor: Color {
        switch self {
        case .carbon: return Color.white
        case .sunset:   return Color(red: 1.00, green: 0.55, blue: 0.25)
        case .forest:   return Color(red: 0.30, green: 0.82, blue: 0.50)
        case .arctic:   return Color(red: 0.40, green: 0.75, blue: 1.00)
        case .neon:     return Color(red: 0.00, green: 1.00, blue: 0.80)
        }
    }

    /// Swatch colors for theme picker preview
    var swatchColors: [Color] {
        [primaryColor, secondaryColor, accentColor]
    }
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedTheme") ?? ""
        self.currentTheme = AppTheme(rawValue: saved) ?? .carbon
    }
}
