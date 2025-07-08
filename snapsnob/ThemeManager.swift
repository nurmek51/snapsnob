import SwiftUI
import Foundation

// MARK: - Theme Manager
/// Manages the app's theme state and provides theme switching functionality
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .system
    @Published var isDarkMode: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "app_theme"
    
    init() {
        loadTheme()
        updateThemeBasedOnSystem()
        
        // Observe system theme changes
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
    
    /// Loads the saved theme preference from UserDefaults
    private func loadTheme() {
        if let themeRawValue = userDefaults.object(forKey: themeKey) as? String,
           let theme = AppTheme(rawValue: themeRawValue) {
            currentTheme = theme
        } else {
            currentTheme = .system
        }
    }
    
    /// Persists the current theme preference
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
    }
    
    /// Sets the app theme and updates UI accordingly
    func setTheme(_ theme: AppTheme) {
        let oldTheme = currentTheme
        currentTheme = theme
        saveTheme()
        updateThemeBasedOnSystem()
        
        // Force update window appearance
        updateWindowAppearance()
        
        // Always trigger a view update when theme changes
        if oldTheme != theme {
            objectWillChange.send()
        }
    }
    
    @objc private func systemThemeChanged() {
        updateThemeBasedOnSystem()
        updateWindowAppearance()
    }
    
    /// Updates isDarkMode based on current theme setting
    private func updateThemeBasedOnSystem() {
        let oldValue = isDarkMode
        let oldTheme = currentTheme
        
        switch currentTheme {
        case .system:
            // Always update isDarkMode to match the current system style
            let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
            isDarkMode = systemIsDark
        case .light:
            isDarkMode = false
        case .dark:
            isDarkMode = true
        }
        
        // Always trigger a view update if theme or isDarkMode changes
        if oldValue != isDarkMode || oldTheme != currentTheme {
            objectWillChange.send()
        }
    }
    
    /// Force update all windows to use the correct appearance
    private func updateWindowAppearance() {
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes
            let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
            
            for windowScene in windowScenes {
                for window in windowScene.windows {
                    switch self.currentTheme {
                    case .system:
                        window.overrideUserInterfaceStyle = .unspecified
                    case .light:
                        window.overrideUserInterfaceStyle = .light
                    case .dark:
                        window.overrideUserInterfaceStyle = .dark
                    }
                    
                    // Force the window to update its appearance
                    window.setNeedsDisplay()
                }
            }
        }
    }
}

// MARK: - App Theme Enum
/// Available theme options for the app
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
/// Centralized color definitions for the app's themes
struct AppColors {
    /// Background color based on theme
    static func background(for isDark: Bool) -> Color {
        isDark ? Color.black : Color.white
    }
    
    /// Secondary background color for cards and containers
    static func secondaryBackground(for isDark: Bool) -> Color {
        isDark ? Color(.systemGray6).opacity(0.3) : Color(.systemGray6)
    }
    
    /// Card background color
    static func cardBackground(for isDark: Bool) -> Color {
        isDark ? Color(.systemGray5).opacity(0.3) : Color(.systemGray6)
    }
    
    /// Primary text color
    static func primaryText(for isDark: Bool) -> Color {
        isDark ? Color.white : Color.black
    }
    
    /// Secondary text color for subtitles and captions
    static func secondaryText(for isDark: Bool) -> Color {
        isDark ? Color(.systemGray) : Color(.systemGray)
    }
    
    /// Accent color for interactive elements
    static func accent(for isDark: Bool) -> Color {
        isDark ? Color.white : Color.black
    }
    
    /// Border color for cards and containers
    static func border(for isDark: Bool) -> Color {
        isDark ? Color(.systemGray4) : Color(.systemGray4)
    }
    
    /// Shadow color for elevated elements
    static func shadow(for isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
} 