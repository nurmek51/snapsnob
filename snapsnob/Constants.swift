import Foundation
import UIKit

// MARK: - App Constants
/// Centralized constants for the SnapSnob app
struct Constants {
    
    // MARK: - UI Strings
    struct Strings {
        // Navigation
        static let home = "Дом"
        static let categories = "Категории"
        static let favorites = "Избранные"
        static let trash = "Корзина"
        
        // Home Screen
        static let photoSeries = "Серии фото"
        static let photosProcessed = "%d/%d фото обработано"
        static let noSinglePhotos = "Нет одиночных фотографий"
        static let allPhotosInSeries = "Все ваши фото являются частью серий"
        static let noMorePhotos = "Больше нет фото"
        
        // Actions
        static let keep = "Оставить"
        static let delete = "Удалить"
        static let restore = "Восстановить"
        static let cancel = "Отмена"
        static let close = "Закрыть"
        static let openSettings = "Открыть настройки"
        
        // Photo Access
        static let photoAccessDenied = "Доступ к фото запрещен"
        static let allowPhotoAccess = "Разрешите доступ к фото в настройках"
        static let loadingPhotos = "Загрузка фотографий..."
        
        // AI Analysis
        static let visionAnalysis = "Анализ Apple Vision"
        static let analyzing = "Анализируем..."
        static let analyzingPhotos = "Анализируем %d фото..."
        static let categoriesVision = "Категории Vision"
        static let duplicates = "Дубликаты"
        static let noDuplicatesFound = "Дубликаты не найдены"
        static let noDuplicatingPhotos = "У вас нет дублирующихся фотографий"
        
        // Duplicates
        static let duplicatePhotos = "Duplicate Photos"
        static let duplicateGroups = "Групп дубликатов"
        static let canDelete = "Можно удалить"
        static let willFree = "Освободится"
        static let deleteAllDuplicates = "Удалить все дубликаты"
        static let freeSpace = "Освободить %@ места"
        static let deleteDuplicatesConfirm = "Удалить дубликаты?"
        static let deleteDuplicatesMessage = "Будет удалено %d дубликатов. Освободится %@ места. Оригиналы будут сохранены."
        
        // Themes
        static let systemTheme = "Системная"
        static let lightTheme = "Светлая"
        static let darkTheme = "Темная"
        static let chooseTheme = "Выберите тему"
        
        // Errors
        static let errorLoadingPhoto = "Ошибка загрузки"
        static let photoUnavailable = "Фото недоступно"
        static let retry = "Повторить"
        
        // Categories
        static let allPhotos = "Все фото"
        static let viewMode = "Режим просмотра"
        static let swipeMode = "Режим свайпа"
        static let normalMode = "Обычный режим"
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