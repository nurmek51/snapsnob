import Foundation
import UIKit

// MARK: - App Constants
/// Centralized constants for the SnapSnob app
struct Constants {
    
    // MARK: - UI Strings
    struct Strings {
        // Navigation
        static var home: String { "navigation.home".localized }
        static var categories: String { "navigation.categories".localized }
        static var favorites: String { "navigation.favorites".localized }
        static var trash: String { "navigation.trash".localized }
        
        // Home Screen
        static var photoSeries: String { "home.photoSeries".localized }
        static var photosProcessed: String { "home.photosProcessed".localized }
        static var noSinglePhotos: String { "home.noSinglePhotos".localized }
        static var allPhotosInSeries: String { "home.allPhotosInSeries".localized }
        static var noMorePhotos: String { "home.noMorePhotos".localized }
        
        // Actions
        static var keep: String { "action.keep".localized }
        static var delete: String { "action.delete".localized }
        static var restore: String { "action.restore".localized }
        static var cancel: String { "action.cancel".localized }
        static var close: String { "action.close".localized }
        static var done: String { "action.done".localized }
        static var openSettings: String { "action.openSettings".localized }
        static var retry: String { "action.retry".localized }
        
        // Photo Access
        static var photoAccessDenied: String { "photo.accessDenied".localized }
        static var allowPhotoAccess: String { "photo.allowAccess".localized }
        static var loadingPhotos: String { "photo.loading".localized }
        static var errorLoadingPhoto: String { "photo.errorLoading".localized }
        static var photoUnavailable: String { "photo.unavailable".localized }
        
        // AI Analysis
        static var visionAnalysis: String { "ai.visionAnalysis".localized }
        static var analyzing: String { "ai.analyzing".localized }
        static var analyzingPhotos: String { "ai.analyzingPhotos".localized }
        static var categoriesVision: String { "ai.categoriesVision".localized }
        static var duplicates: String { "ai.duplicates".localized }
        static var noDuplicatesFound: String { "ai.noDuplicatesFound".localized }
        static var noDuplicatingPhotos: String { "ai.noDuplicatingPhotos".localized }
        static var analyzePhotos: String { "ai.analyzePhotos".localized }
        static var maximumAccuracy: String { "ai.maximumAccuracy".localized }
        
        // Duplicates
        static var duplicatePhotos: String { "duplicates.title".localized }
        static var duplicateGroups: String { "duplicates.groups".localized }
        static var canDelete: String { "duplicates.canDelete".localized }
        static var willFree: String { "duplicates.willFree".localized }
        static var deleteAllDuplicates: String { "duplicates.deleteAll".localized }
        static var freeSpace: String { "duplicates.freeSpace".localized }
        static var deleteDuplicatesConfirm: String { "duplicates.confirmDelete".localized }
        static var deleteDuplicatesMessage: String { "duplicates.deleteMessage".localized }
        
        // Themes
        static var systemTheme: String { "theme.system".localized }
        static var lightTheme: String { "theme.light".localized }
        static var darkTheme: String { "theme.dark".localized }
        static var chooseTheme: String { "theme.choose".localized }
        static var themeDescription: String { "theme.description".localized }
        
        // Categories
        static var allPhotos: String { "category.allPhotos".localized }
        static var viewMode: String { "category.viewMode".localized }
        static var swipeMode: String { "category.swipeMode".localized }
        static var normalMode: String { "category.normalMode".localized }
        
        // Trash
        static var trashEmpty: String { "trash.empty".localized }
        static var trashEmptyDescription: String { "trash.emptyDescription".localized }
        static var trashTitleWithCount: String { "trash.titleWithCount".localized }
        
        // Favorites
        static var favoritesEmpty: String { "favorites.empty".localized }
        static var favoritesEmptyDescription: String { "favorites.emptyDescription".localized }
    }
    
    // MARK: - Layout Constants
    struct Layout {
        // Adaptive layout helper
        private static var deviceInfo: DeviceInfo { DeviceInfo.shared }
        
        // Dynamic padding based on device size
        static var standardPadding: CGFloat { deviceInfo.screenSize.horizontalPadding }
        static var compactPadding: CGFloat { deviceInfo.screenSize.horizontalPadding * 0.8 }
        static var smallPadding: CGFloat { deviceInfo.screenSize.horizontalPadding * 0.4 }
        
        // Dynamic corner radius based on device size
        static var cardCornerRadius: CGFloat { deviceInfo.screenSize.cornerRadius * 1.5 }
        static var standardCornerRadius: CGFloat { deviceInfo.screenSize.cornerRadius }
        static var smallCornerRadius: CGFloat { deviceInfo.screenSize.cornerRadius * 0.75 }
        
        // Dynamic grid settings
        static var gridSpacing: CGFloat { deviceInfo.screenSize.gridSpacing }
        static var photoGridColumns: Int { deviceInfo.screenSize.gridColumns }
        
        // Legacy constants for backwards compatibility
        static let iPadPadding: CGFloat = 40
        static let iPadCompactPadding: CGFloat = 30
        
        // Animation Durations
        static let standardAnimationDuration: Double = 0.3
        static let quickAnimationDuration: Double = 0.2
        static let slowAnimationDuration: Double = 0.6
        
        // Adaptive font sizes
        static var titleFontSize: CGFloat { deviceInfo.screenSize.fontSize.title }
        static var bodyFontSize: CGFloat { deviceInfo.screenSize.fontSize.body }
        static var captionFontSize: CGFloat { deviceInfo.screenSize.fontSize.caption }
    }
    
    // MARK: - Photo Processing
    struct PhotoProcessing {
        // Series Detection
        static let seriesTimeThreshold: TimeInterval = 60 // 1 minute
        static let nonSeriesTimeThreshold: TimeInterval = 120 // 2 minutes
        static let minSeriesSize = 3
        static let maxSeriesToShow = 15
        
        // Adaptive thumbnail sizes based on device
        static var defaultThumbnailSize: CGSize {
            let deviceInfo = DeviceInfo.shared
            switch deviceInfo.screenSize {
            case .compact:
                return CGSize(width: 300, height: 300)
            case .standard:
                return CGSize(width: 400, height: 400)
            case .plus, .max:
                return CGSize(width: 500, height: 500)
            case .iPad:
                return CGSize(width: 600, height: 600)
            case .iPadPro:
                return CGSize(width: 800, height: 800)
            }
        }
        
        static var smallThumbnailSize: CGSize {
            let deviceInfo = DeviceInfo.shared
            switch deviceInfo.screenSize {
            case .compact:
                return CGSize(width: 80, height: 80)
            case .standard:
                return CGSize(width: 100, height: 100)
            case .plus, .max:
                return CGSize(width: 120, height: 120)
            case .iPad:
                return CGSize(width: 150, height: 150)
            case .iPadPro:
                return CGSize(width: 200, height: 200)
            }
        }
        
        static var largeThumbnailSize: CGSize {
            let deviceInfo = DeviceInfo.shared
            switch deviceInfo.screenSize {
            case .compact:
                return CGSize(width: 600, height: 600)
            case .standard:
                return CGSize(width: 800, height: 800)
            case .plus, .max:
                return CGSize(width: 1000, height: 1000)
            case .iPad:
                return CGSize(width: 1200, height: 1200)
            case .iPadPro:
                return CGSize(width: 1500, height: 1500)
            }
        }
        
        // Batch Processing
        static let visionBatchSize = 80
        static let duplicateDetectionWindowSize = 25
        static let duplicateSimilarityThreshold: Float = 1.5
        
        // Cache
        static let imageCacheCountLimit = 100
        static let imageCacheSizeLimit = 50 * 1024 * 1024 // 50MB
        static let cacheValidityDays = 30
    }
    
    // MARK: - Device Helpers
    struct Device {
        static var isIPad: Bool {
            DeviceInfo.shared.isIPad
        }
        
        static var isIPhone: Bool {
            DeviceInfo.shared.isIPhone
        }
        
        static var screenScale: CGFloat {
            UIScreen.main.scale
        }
        
        static var screenSize: DeviceInfo.ScreenSize {
            DeviceInfo.shared.screenSize
        }
        
        static var cardSize: CGSize {
            DeviceInfo.shared.cardSize()
        }
    }
    
    // MARK: - User Defaults Keys
    struct UserDefaultsKeys {
        static let currentTheme = "app_theme"
        static let reviewedPhotoIDs = "reviewed_photo_ids"
        static let trashedPhotoIDs = "trashed_photo_ids"
        static let aiAnalysisCache = "AIAnalysisCache"
    }
} 