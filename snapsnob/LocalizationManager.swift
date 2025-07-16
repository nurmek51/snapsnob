import Foundation
import SwiftUI

// MARK: - Supported Languages
enum SupportedLanguage: String, CaseIterable {
    case english = "en"
    case russian = "ru"
    
    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .russian:
            return "Русский"
        }
    }
    
    var nativeName: String {
        switch self {
        case .english:
            return "English"
        case .russian:
            return "Русский"
        }
    }
}

// MARK: - Localization Manager
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: SupportedLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguage")
            updateBundle()
        }
    }
    
    @Published var isDeveloperOverride: Bool = false
    
    private var bundle: Bundle = Bundle.main
    
    private init() {
        // Check for developer override first
        if let overrideLanguage = UserDefaults.standard.string(forKey: "DeveloperLanguageOverride"),
           let language = SupportedLanguage(rawValue: overrideLanguage) {
            self.currentLanguage = language
            self.isDeveloperOverride = true
        } else if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage"),
                  let language = SupportedLanguage(rawValue: savedLanguage) {
            // Use saved language preference
            self.currentLanguage = language
        } else {
            // Detect system language
            self.currentLanguage = Self.detectSystemLanguage()
        }
        
        updateBundle()
    }
    
    // MARK: - System Language Detection
    private static func detectSystemLanguage() -> SupportedLanguage {
        // Get preferred languages from system
        let preferredLanguages = Locale.preferredLanguages
        
        // Check each preferred language against supported languages
        for preferredLang in preferredLanguages {
            let langCode = String(preferredLang.prefix(2))
            
            for supportedLang in SupportedLanguage.allCases {
                if langCode == supportedLang.rawValue {
                    return supportedLang
                }
            }
        }
        
        // Default to English if no supported language found
        return .english
    }
    
    // MARK: - Bundle Management
    private func updateBundle() {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to main bundle if localization bundle not found
            self.bundle = Bundle.main
            return
        }
        
        self.bundle = bundle
    }
    
    // MARK: - Localization Methods
    func localizedString(for key: String, comment: String = "") -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    func localizedString(for key: String, arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, arguments: arguments)
    }
    
    // MARK: - Language Management
    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
        isDeveloperOverride = false
        UserDefaults.standard.removeObject(forKey: "DeveloperLanguageOverride")
    }
    
    func setDeveloperOverride(_ language: SupportedLanguage) {
        isDeveloperOverride = true
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "DeveloperLanguageOverride")
    }
    
    func clearDeveloperOverride() {
        isDeveloperOverride = false
        UserDefaults.standard.removeObject(forKey: "DeveloperLanguageOverride")
        
        // Revert to system language
        currentLanguage = Self.detectSystemLanguage()
    }
    
    func resetToSystemLanguage() {
        UserDefaults.standard.removeObject(forKey: "AppLanguage")
        UserDefaults.standard.removeObject(forKey: "DeveloperLanguageOverride")
        isDeveloperOverride = false
        currentLanguage = Self.detectSystemLanguage()
    }
    
    // MARK: - Convenience Methods
    var isRTL: Bool {
        // Add RTL language support if needed in the future
        return false
    }
    
    var currentLocale: Locale {
        return Locale(identifier: currentLanguage.rawValue)
    }
}

// MARK: - Localization Helper Extension
extension String {
    /// Localizes the string using the current language
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    /// Localizes the string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        return LocalizationManager.shared.localizedString(for: self, arguments: arguments)
    }
}

// MARK: - SwiftUI Environment Key
struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localizationManager: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
} 