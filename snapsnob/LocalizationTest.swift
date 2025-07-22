import Foundation

// MARK: - Localization Test Helper
struct LocalizationTest {
    static func testLocalization() {
        let manager = LocalizationManager.shared
        
        print("=== Localization Test ===")
        print("Current language: \(manager.currentLanguage.displayName)")
        print("Current locale: \(manager.currentLocale.identifier)")
        
        // Test some key strings
        let testKeys = [
            "navigation.home",
            "action.keep",
            "action.delete",
            "photo.accessDenied",
            "ai.analyzing",
            "duplicates.title",
            "theme.system",
            "category.allPhotos",
            "trash.empty",
            "favorites.title",
            "settings.title",
            "language.title",
            "general.loading",
            "photoCategory.people",
            "analysis.title",
            "common.noData",
            "favorites.totalPhotos",
            "onboarding.skip",
            "toast.photoAddedToTrash"
        ]
        
        for key in testKeys {
            let localized = manager.localizedString(for: key)
            print("\(key): \(localized)")
        }
        
        print("=== End Test ===")
    }
    
    static func testLanguageSwitching() {
        let manager = LocalizationManager.shared
        let originalLanguage = manager.currentLanguage
        
        print("=== Language Switching Test ===")
        
        for language in SupportedLanguage.allCases {
            manager.setLanguage(language)
            print("Switched to \(language.displayName)")
            print("Home: \(manager.localizedString(for: "navigation.home"))")
            print("Keep: \(manager.localizedString(for: "action.keep"))")
            print("Delete: \(manager.localizedString(for: "action.delete"))")
            print("---")
        }
        
        // Restore original language
        manager.setLanguage(originalLanguage)
        print("Restored to \(originalLanguage.displayName)")
        print("=== End Language Switching Test ===")
    }
} 