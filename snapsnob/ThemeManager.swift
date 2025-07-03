import SwiftUI
import Foundation

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .system
    @Published var isDarkMode: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "app_theme"
    
    init() {
        loadTheme()
        updateThemeBasedOnSystem()
        
        // Наблюдаем за изменениями системной темы
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemThemeChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadTheme() {
        if let themeRawValue = userDefaults.object(forKey: themeKey) as? String,
           let theme = AppTheme(rawValue: themeRawValue) {
            currentTheme = theme
        } else {
            currentTheme = .system
        }
    }
    
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveTheme()
        updateThemeBasedOnSystem()
    }
    
    @objc private func systemThemeChanged() {
        updateThemeBasedOnSystem()
    }
    
    private func updateThemeBasedOnSystem() {
        switch currentTheme {
        case .system:
            isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        case .light:
            isDarkMode = false
        case .dark:
            isDarkMode = true
        }
    }
}

// MARK: - App Theme Enum
enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system:
            return "Системная"
        case .light:
            return "Светлая"
        case .dark:
            return "Темная"
        }
    }
    
    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
}

// MARK: - Theme Colors
struct AppColors {
    static func background(for isDark: Bool) -> Color {
        isDark ? Color.black : Color.white
    }
    
    static func secondaryBackground(for isDark: Bool) -> Color {
        isDark ? Color(.systemGray6).opacity(0.3) : Color(.systemGray6)
    }
    
    static func cardBackground(for isDark: Bool) -> Color {
        isDark ? Color(.systemGray5).opacity(0.3) : Color(.systemGray6)
    }
    
    static func primaryText(for isDark: Bool) -> Color {
        isDark ? Color.white : Color.black
    }
    
    static func secondaryText(for isDark: Bool) -> Color {
        isDark ? Color(.systemGray) : Color(.systemGray)
    }
    
    static func accent(for isDark: Bool) -> Color {
        isDark ? Color.white : Color.black
    }
    
    static func border(for isDark: Bool) -> Color {
        isDark ? Color(.systemGray4) : Color(.systemGray4)
    }
    
    static func shadow(for isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
}

// MARK: - Convenience Methods for AppColors
extension AppColors {
    static func background() -> Color {
        return background(for: UITraitCollection.current.userInterfaceStyle == .dark)
    }
    
    static func secondaryBackground() -> Color {
        return secondaryBackground(for: UITraitCollection.current.userInterfaceStyle == .dark)
    }
    
    static func cardBackground() -> Color {
        return cardBackground(for: UITraitCollection.current.userInterfaceStyle == .dark)
    }
    
    static func primaryText() -> Color {
        return primaryText(for: UITraitCollection.current.userInterfaceStyle == .dark)
    }
    
    static func secondaryText() -> Color {
        return secondaryText(for: UITraitCollection.current.userInterfaceStyle == .dark)
    }
    
    static func accent() -> Color {
        return accent(for: UITraitCollection.current.userInterfaceStyle == .dark)
    }
    
    static func border() -> Color {
        return border(for: UITraitCollection.current.userInterfaceStyle == .dark)
    }
    
    static func shadow() -> Color {
        return shadow(for: UITraitCollection.current.userInterfaceStyle == .dark)
    }
} 