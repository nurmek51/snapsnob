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
        // Card Sizes
        static let cardCornerRadius: CGFloat = 24
        static let standardCornerRadius: CGFloat = 16
        static let smallCornerRadius: CGFloat = 12
        
        // Padding
        static let standardPadding: CGFloat = 20
        static let compactPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        
        // iPad specific
        static let iPadPadding: CGFloat = 40
        static let iPadCompactPadding: CGFloat = 30
        
        // Photo Grid
        static let gridSpacing: CGFloat = 8
        static let photoGridColumns = 3
        
        // Animation Durations
        static let standardAnimationDuration: Double = 0.3
        static let quickAnimationDuration: Double = 0.2
        static let slowAnimationDuration: Double = 0.6
    }
    
    // MARK: - Photo Processing
    struct PhotoProcessing {
        // Series Detection
        static let seriesTimeThreshold: TimeInterval = 60 // 1 minute
        static let nonSeriesTimeThreshold: TimeInterval = 120 // 2 minutes
        static let minSeriesSize = 3
        static let maxSeriesToShow = 15
        
        // Thumbnail Sizes
        static let defaultThumbnailSize = CGSize(width: 400, height: 400)
        static let smallThumbnailSize = CGSize(width: 100, height: 100)
        static let largeThumbnailSize = CGSize(width: 800, height: 800)
        
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
            UIDevice.current.userInterfaceIdiom == .pad
        }
        
        static var screenScale: CGFloat {
            UIScreen.main.scale
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