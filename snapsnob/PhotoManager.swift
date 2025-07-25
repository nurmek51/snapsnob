import SwiftUI
import Photos
import PhotosUI
import Foundation
import FirebaseAnalytics

// MARK: - Photo Model
struct Photo: Identifiable, Hashable {
    let id = UUID()
    let asset: PHAsset
    var isTrashed: Bool = false
    var category: PhotoCategory?
    var qualityScore: Double = 0.0
    var dateAdded: Date
    var dateMovedToTrash: Date? = nil // Timestamp when photo was moved to trash
    var features: [Float]? // Feature embeddings for duplicate/series detection
    var categoryConfidence: Float = 0.0
    var isFavorite: Bool = false // Whether the user marked this photo as favourite
    var isReviewed: Bool = false // Photo has been kept (skipped) by user
    var isSuperStar: Bool = false // Whether the user marked this photo as super star (best of the best)
    var storyInteraction: String? = nil // Track story interactions: "keep", "trash", nil = not interacted
    
    var creationDate: Date {
        asset.creationDate ?? Date()
    }
    
    var assetIdentifier: String {
        asset.localIdentifier
    }
    
    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: – Enable cross-concurrency transfer of the lightweight `Photo` value type.
// The struct contains a reference type (`PHAsset`) which is not Sendable, but we only ever
// pass `Photo` between tasks for read-only purposes. Declaring it as `@unchecked Sendable`
// is therefore safe and silences Swift 6's strict sendability checks.
extension Photo: @unchecked Sendable {}

// MARK: - Photo Category
enum PhotoCategory: String, CaseIterable, Codable, Identifiable {
    var id: String { self.rawValue }
    case nature = "nature"
    case people = "people"
    case food = "food"
    case animals = "animals"
    case architecture = "architecture"
    case transport = "transport"
    case technology = "technology"
    case art = "art"
    case events = "events"
    case sports = "sports"
    case travel = "travel"
    case home = "home"
    case work = "work"
    case shopping = "shopping"
    case entertainment = "entertainment"
    case other = "other"
    
    var localizedName: String {
        switch self {
        case .nature: return "photoCategory.nature".localized
        case .people: return "photoCategory.people".localized
        case .food: return "photoCategory.food".localized
        case .animals: return "photoCategory.animals".localized
        case .architecture: return "photoCategory.buildings".localized
        case .transport: return "photoCategory.vehicles".localized
        case .technology: return "photoCategory.objects".localized
        case .art: return "photoCategory.objects".localized
        case .events: return "photoCategory.people".localized
        case .sports: return "photoCategory.objects".localized
        case .travel: return "photoCategory.landscapes".localized
        case .home: return "photoCategory.objects".localized
        case .work: return "photoCategory.documents".localized
        case .shopping: return "photoCategory.objects".localized
        case .entertainment: return "photoCategory.objects".localized
        case .other: return "photoCategory.other".localized
        }
    }
    
    var icon: String {
        switch self {
        case .nature: return "leaf.fill"
        case .people: return "person.2.fill"
        case .food: return "fork.knife"
        case .animals: return "pawprint.fill"
        case .architecture: return "building.2.fill"
        case .transport: return "car.fill"
        case .technology: return "laptopcomputer"
        case .art: return "paintbrush.fill"
        case .events: return "party.popper.fill"
        case .sports: return "sportscourt.fill"
        case .travel: return "airplane"
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .shopping: return "bag.fill"
        case .entertainment: return "tv.fill"
        case .other: return "square.grid.2x2"
        }
    }
    
    var color: Color {
        switch self {
        case .nature: return .green
        case .people: return .purple
        case .food: return .red
        case .animals: return .orange
        case .architecture: return .blue
        case .transport: return .gray
        case .technology: return .cyan
        case .art: return .pink
        case .events: return .yellow
        case .sports: return .indigo
        case .travel: return .teal
        case .home: return .brown
        case .work: return .black
        case .shopping: return .mint
        case .entertainment: return .purple
        case .other: return .secondary
        }
    }
    
    // Keywords for better categorization
    var keywords: [String] {
        switch self {
        case .nature:
            return ["tree", "forest", "mountain", "sky", "cloud", "sunset", "sunrise", "landscape", "flower", "plant", "beach", "ocean", "lake", "river", "garden", "park", "outdoor"]
        case .people:
            return [
                "person", "people", "face", "family", "friend", "selfie", "portrait", "group", "wedding", "party", "celebration",
                "woman", "man", "girl", "boy", "child", "children", "kid", "kids", "human"
            ]
        case .food:
            return ["food", "meal", "restaurant", "kitchen", "cooking", "dinner", "lunch", "breakfast", "coffee", "drink", "cake", "pizza", "burger"]
        case .animals:
            return [
                "animal", "animals", "pet", "pets", "dog", "puppy", "cat", "kitten", "bird", "wildlife", "zoo", "farm", "horse", "fish", "cow", "sheep", "giraffe", "elephant"
            ]
        case .architecture:
            return ["building", "house", "church", "bridge", "tower", "castle", "architecture", "city", "street", "urban"]
        case .transport:
            return ["car", "bus", "train", "plane", "bike", "motorcycle", "truck", "boat", "ship", "vehicle", "transportation"]
        case .technology:
            return ["computer", "phone", "laptop", "screen", "device", "gadget", "electronics", "tech", "software", "app"]
        case .art:
            return ["art", "painting", "drawing", "sculpture", "museum", "gallery", "creative", "design", "artwork"]
        case .events:
            return ["birthday", "party", "wedding", "graduation", "concert", "festival", "holiday", "celebration", "ceremony"]
        case .sports:
            return ["sports", "football", "basketball", "tennis", "gym", "fitness", "exercise", "game", "stadium", "athletic"]
        case .travel:
            return ["travel", "vacation", "trip", "tourist", "hotel", "airport", "suitcase", "passport", "adventure", "explore"]
        case .home:
            return ["home", "room", "bedroom", "living", "kitchen", "bathroom", "furniture", "interior", "decoration", "family"]
        case .work:
            return ["office", "work", "meeting", "business", "desk", "computer", "document", "presentation", "workplace", "professional"]
        case .shopping:
            return ["shopping", "store", "mall", "market", "clothes", "purchase", "retail", "fashion", "buying", "product"]
        case .entertainment:
            return ["movie", "tv", "game", "music", "book", "theater", "entertainment", "fun", "hobby", "leisure"]
        case .other:
            return []
        }
    }
}

// MARK: - Photo Series Model
struct PhotoSeriesData: Identifiable {
    let id = UUID()
    let photos: [Photo]
    let thumbnailPhoto: Photo
    var title: String
    var isViewed: Bool = false
    var isCompleted: Bool = false // Track if user completed the entire story
    var completedAt: Date? = nil // When the story was completed
    
    var dateRange: String {
        guard let firstDate = photos.first?.creationDate,
              let lastDate = photos.last?.creationDate else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if Calendar.current.isDate(firstDate, inSameDayAs: lastDate) {
            return formatter.string(from: firstDate)
        } else {
            return "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        }
    }
}

// MARK: - Photo Album Model
struct PhotoAlbum: Identifiable {
    let id = UUID()
    let title: String
    let photos: [Photo]
    var thumbnailPhoto: Photo? { photos.first }
}

// MARK: - Photo Manager
class PhotoManager: ObservableObject {
    @Published var allPhotos: [Photo] = []
    @Published var displayPhotos: [Photo] = [] // Photos not trashed
    @Published var trashedPhotos: [Photo] = []
    @Published var photoSeries: [PhotoSeriesData] = []
    @Published var isLoading = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var albums: [PhotoAlbum] = []
    @Published var categorizedPhotos: [PhotoCategory: [Photo]] = [:]
    
    // --- Add pageSize for random sampling ---
    private let pageSize = 500 // Number of random non-series photos to show in feed
    
    // MARK: - Pagination Support for Large Libraries
    // Remove or bypass pagination-related properties and methods
    // (currentPage, hasMorePhotos, loadPhotosPage, loadMorePhotosIfNeeded, loadedAssetCount)
    
    // MARK: - Feed Configuration Constants
    /// Time interval (in seconds) that is treated as a "series" gap. Photos that are taken within this
    /// interval from another photo are considered to be part of a series and therefore excluded from the
    /// single-photo feed that is displayed in `HomeView`.
    private let nonSeriesTimeThreshold: TimeInterval = 120 // 2 minutes
    
    private let imageManager = PHCachingImageManager()
    private var allAssets: PHFetchResult<PHAsset>?
    
    /// Dedicated queue for heavy photo processing (series detection, feed building) to keep UI responsive.
    private let processingQueue = DispatchQueue(label: "com.nfac.PhotoManager.processing", qos: .userInitiated)
    
    // NEW: Queue for background photo loading
    private let loadingQueue = DispatchQueue(label: "com.nfac.PhotoManager.loading", qos: .background)
    
    // NEW: Common thumbnail size used across HomeView cards & Story circles. Adjust once here to keep cache coherent.
    static let defaultThumbnailSize = CGSize(width: 400, height: 400)
    
    private let reviewedKey = "reviewed_photo_ids"
    private let trashedKey = "trashed_photo_ids"
    private var reviewedPhotoIDs: Set<String> = []
    private var trashedPhotoIDs: Set<String> = []
    private let defaults = UserDefaults.standard
    
    init() {
        // Load persisted flags BEFORE we start processing so we can apply them immediately
        loadPersistedFlags()
        checkPhotoLibraryAuthorization()
    }
    
    // MARK: - Optimized Photo Loading: Random Non-Series Sample
    /// Loads up to 500 randomly sampled non-series photos from the entire gallery history for the feed.
    func loadRandomNonSeriesPhotos() {
        guard !isLoading else { return }
        isLoading = true

        loadingQueue.async { [weak self] in
            guard let self = self else { return }

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.includeHiddenAssets = false
            let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            var allPhotos: [Photo] = []
            allPhotos.reserveCapacity(allAssets.count)
            allAssets.enumerateObjects { asset, _, _ in
                var photo = Photo(asset: asset, dateAdded: Date())
                photo.isFavorite = asset.isFavorite
                if self.reviewedPhotoIDs.contains(asset.localIdentifier) {
                    photo.isReviewed = true
                }
                if self.trashedPhotoIDs.contains(asset.localIdentifier) {
                    photo.isTrashed = true
                }
                allPhotos.append(photo)
            }

            // --- Always detect series from ALL non-trashed photos for stories conveyor ---
            let allNonTrashedPhotos = allPhotos.filter { !$0.isTrashed }
            let series = self.calculateSeries(from: allNonTrashedPhotos)
            let seriesPhotoIds = Set(series.flatMap { $0.photos.map { $0.asset.localIdentifier } })

            // Filter out series, trashed, reviewed, and favorites for the feed
            let nonSeriesPhotos = allPhotos.filter {
                !seriesPhotoIds.contains($0.asset.localIdentifier) &&
                !$0.isTrashed &&
                !$0.isReviewed &&
                !$0.isFavorite
            }

            // Randomly sample up to 500
            let sampleCount = min(self.pageSize, nonSeriesPhotos.count)
            let randomSample = sampleCount == nonSeriesPhotos.count ? nonSeriesPhotos : Array(nonSeriesPhotos.shuffled().prefix(sampleCount))

            DispatchQueue.main.async {
                self.allPhotos = allPhotos // Keep all for album/series logic
                // Remove direct assignments to displayPhotos and photoSeries
                self.isLoading = false
                self.updateDisplayPhotos() // Ensure all published properties are up-to-date
                self.loadAlbums()
            }
        }
    }
    
    // MARK: - Incremental Series Detection
    private func detectPhotoSeriesIncremental(newPhotos: [Photo]) {
        // Process only camera photos from new batch
        let newCameraPhotos = newPhotos.filter { !$0.isTrashed && isCameraPhoto($0.asset) }
        guard !newCameraPhotos.isEmpty else { return }
        
        // This is a simplified incremental approach
        // In production, you'd want to merge with existing series more intelligently
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.detectPhotoSeries()
        }
    }
    
    // MARK: - Load Albums (User Folders)
    private func loadAlbums() {
        var loadedAlbums: [PhotoAlbum] = []

        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)

        userAlbums.enumerateObjects { [weak self] collection, _, _ in
            guard let self else { return }
            let assetsFetch = PHAsset.fetchAssets(in: collection, options: nil)
            guard assetsFetch.count > 0 else { return }

            var photos: [Photo] = []
            assetsFetch.enumerateObjects { asset, _, _ in
                if let existing = self.allPhotos.first(where: { $0.asset.localIdentifier == asset.localIdentifier }) {
                    photos.append(existing)
                } else {
                    var albumPhoto = Photo(asset: asset, dateAdded: Date())
                    albumPhoto.isFavorite = asset.isFavorite
                    photos.append(albumPhoto)
                }
            }

            let album = PhotoAlbum(title: collection.localizedTitle ?? "category.albums".localized, photos: photos)
            loadedAlbums.append(album)
        }

        // Add system "All photos" album at the beginning
        let allAlbum = PhotoAlbum(title: "category.allPhotos".localized, photos: self.allPhotos)
        loadedAlbums.insert(allAlbum, at: 0)

        DispatchQueue.main.async {
            self.albums = loadedAlbums
        }
    }
    
    // MARK: - Photo Series Detection
    func detectPhotoSeries() {
        print("🔍 Starting camera-only time-based series detection")
        let cameraPhotos = displayPhotos.filter { isCameraPhoto($0.asset) }
        guard !cameraPhotos.isEmpty else {
            photoSeries = []
            return
        }

        var series: [PhotoSeriesData] = []
        var currentSeriesPhotos: [Photo] = []
        let seriesTimeThreshold: TimeInterval = 60 // 1 minute
        let minSeriesSize = 3 // at least 3 camera shots constitute a series

        for (index, photo) in cameraPhotos.enumerated() {
            if currentSeriesPhotos.isEmpty {
                currentSeriesPhotos.append(photo)
            } else {
                let lastPhoto = currentSeriesPhotos.last!
                let timeDifference = abs(photo.creationDate.timeIntervalSince(lastPhoto.creationDate))
                if timeDifference <= seriesTimeThreshold {
                    currentSeriesPhotos.append(photo)
                } else {
                    if currentSeriesPhotos.count >= minSeriesSize {
                        let seriesData = PhotoSeriesData(
                            photos: currentSeriesPhotos,
                            thumbnailPhoto: currentSeriesPhotos.first!,
                            title: getTitleForSeries(currentSeriesPhotos)
                        )
                        series.append(seriesData)
                        print("📸 Created camera series '\(seriesData.title)' with \(currentSeriesPhotos.count) photos")
                    }
                    currentSeriesPhotos = [photo]
                }
            }

            // Handle last element
            if index == cameraPhotos.count - 1 && currentSeriesPhotos.count >= minSeriesSize {
                let seriesData = PhotoSeriesData(
                    photos: currentSeriesPhotos,
                    thumbnailPhoto: currentSeriesPhotos.first!,
                    title: getTitleForSeries(currentSeriesPhotos)
                )
                series.append(seriesData)
            }
        }

        // Sort newest first and keep max 15
        series.sort { ($0.photos.first?.creationDate ?? Date()) > ($1.photos.first?.creationDate ?? Date()) }
        photoSeries = Array(series.prefix(15))
        print("🔍 Camera series detection completed. Created \(photoSeries.count) series")
    }
    
    // Update photo series with AI-detected series
    func updateWithAIDetectedSeries(_ aiSeries: [PhotoSeriesData]) {
        if !aiSeries.isEmpty {
            print("📸 Updating with \(aiSeries.count) AI-detected series")
            photoSeries = aiSeries
        }
    }
    
    private func getTitleForSeries(_ photos: [Photo]) -> String {
        guard let firstPhoto = photos.first else { return "home.photoSeries".localized }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: firstPhoto.creationDate)
        
        // Add day if not today
        let calendar = Calendar.current
        if !calendar.isDateInToday(firstPhoto.creationDate) {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "dd.MM"
            return "\(dayFormatter.string(from: firstPhoto.creationDate)) \(timeString)"
        }
        
        return "\(timeString)"
    }
    
    // MARK: - Photo Actions
    

    
    /// Moves a photo to trash
    /// - Parameter photo: The photo to move to trash
    func moveToTrash(_ photo: Photo) {
        if let index = allPhotos.firstIndex(where: { $0.id == photo.id }) {
            allPhotos[index].isTrashed = true
            allPhotos[index].dateMovedToTrash = Date() // Set timestamp when moved to trash
            trashedPhotoIDs.insert(photo.asset.localIdentifier)
            reviewedPhotoIDs.remove(photo.asset.localIdentifier) // ensure not marked reviewed simultaneously
            persistFlags()
            updateDisplayPhotos()
        }
    }
    
    /// Restores a photo from trash
    /// - Parameter photo: The photo to restore
    func restoreFromTrash(_ photo: Photo) {
        if let index = allPhotos.firstIndex(where: { $0.id == photo.id }) {
            allPhotos[index].isTrashed = false
            allPhotos[index].dateMovedToTrash = nil // Clear trash timestamp when restored
            trashedPhotoIDs.remove(photo.asset.localIdentifier)
            persistFlags()
            
            // Update display photos synchronously to ensure immediate availability
            let newDisplay = self.allPhotos.filter { !$0.isTrashed && !$0.isReviewed }
            let newTrash = self.allPhotos.filter { $0.isTrashed }
            
            DispatchQueue.main.async {
                // Update arrays immediately
                self.displayPhotos = newDisplay.sorted { $0.creationDate > $1.creationDate }
                self.trashedPhotos = newTrash.sorted { ($0.dateMovedToTrash ?? Date.distantPast) > ($1.dateMovedToTrash ?? Date.distantPast) }
                
                // Post notification after displayPhotos is updated
                NotificationCenter.default.post(
                    name: NSNotification.Name("PhotoRestoredFromTrash"), 
                    object: nil, 
                    userInfo: ["photoId": photo.id]
                )
            }
            
            // Update series detection in background
            updateDisplayPhotos()
        }
    }
    
    /// Permanently deletes a photo from the device's photo library
    /// - Parameter photo: The photo to delete permanently
    func permanentlyDeletePhoto(_ photo: Photo) {
        // Delete the asset from the Photos library and update local caches
        PHPhotoLibrary.shared().performChanges({
            // Request the deletion of the underlying PHAsset
            PHAssetChangeRequest.deleteAssets([photo.asset] as NSArray)
        }) { [weak self] success, error in
            guard let self else { return }
            if success {
                // Remove from local arrays on the main queue to keep @Published properties in sync with UI
                DispatchQueue.main.async {
                    self.allPhotos.removeAll { $0.id == photo.id }
                    self.updateDisplayPhotos()
                }
            } else if let error {
                print("❌ Failed to delete asset: \(error.localizedDescription)")
            }
        }
    }
    
    /// Clear all photos from trash (permanently delete them)
    func clearAllTrash() {
        let photosToDelete = trashedPhotos
        
        // Delete all trashed photos from the Photos library
        PHPhotoLibrary.shared().performChanges({
            let assetsToDelete = photosToDelete.map { $0.asset }
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }) { [weak self] success, error in
            guard let self else { return }
            if success {
                DispatchQueue.main.async {
                    // Remove from local arrays
                    for photo in photosToDelete {
                        self.allPhotos.removeAll { $0.id == photo.id }
                    }
                    self.updateDisplayPhotos()
                }
            } else if let error {
                print("❌ Failed to clear all trash: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Favorites
    /// Mark or unmark a photo as favourite.
    func setFavorite(_ photo: Photo, isFavorite: Bool = true) {
        // 1. Update local model copies (allPhotos & displayPhotos) without rebuilding the whole feed.
        if let index = allPhotos.firstIndex(where: { $0.id == photo.id }) {
            allPhotos[index].isFavorite = isFavorite
        }

        if let displayIndex = displayPhotos.firstIndex(where: { $0.id == photo.id }) {
            displayPhotos[displayIndex].isFavorite = isFavorite
        }

        // Manually send change notification so SwiftUI views refresh without having to call the heavy `updateDisplayPhotos()` pipeline.
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        // 2. Persist to Photos library so the change is reflected system-wide (the system album "Избранное").
        PHPhotoLibrary.shared().performChanges {
            let req = PHAssetChangeRequest(for: photo.asset)
            req.isFavorite = isFavorite
        } completionHandler: { success, error in
            if !success {
                print("❌ Failed to update system favourite flag: \(error?.localizedDescription ?? "unknown")")
            }
            // --- Always update display photos after favorite change ---
            DispatchQueue.main.async {
                self.updateDisplayPhotos()
            }
        }
    }
    
    /// Toggle favourite status for a given photo.
    func toggleFavorite(_ photo: Photo) {
        if let updated = allPhotos.first(where: { $0.id == photo.id }) {
            setFavorite(updated, isFavorite: !updated.isFavorite)
        }
    }
    
    // Total number of favourite (starred) photos
    var favoritePhotosCount: Int {
        displayPhotos.filter { $0.isFavorite }.count
    }
    
    // MARK: - Super Star / Best of the Best
    /// Mark or unmark a photo as super star (best of the best).
    func setSuperStar(_ photo: Photo, isSuperStar: Bool = true) {
        // Update local model copies
        if let index = allPhotos.firstIndex(where: { $0.id == photo.id }) {
            allPhotos[index].isSuperStar = isSuperStar
        }

        if let displayIndex = displayPhotos.firstIndex(where: { $0.id == photo.id }) {
            displayPhotos[displayIndex].isSuperStar = isSuperStar
        }

        // Send change notification
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    /// Toggle super star status for a given photo.
    func toggleSuperStar(_ photo: Photo) {
        if let updated = allPhotos.first(where: { $0.id == photo.id }) {
            setSuperStar(updated, isSuperStar: !updated.isSuperStar)
        }
    }
    
    // Total number of super star photos
    var superStarPhotosCount: Int {
        displayPhotos.filter { $0.isSuperStar }.count
    }
    
    // MARK: - Reviewed / Keep
    func markReviewed(_ photo: Photo) {
        if let index = allPhotos.firstIndex(where: { $0.id == photo.id }) {
            allPhotos[index].isReviewed = true
            reviewedPhotoIDs.insert(photo.asset.localIdentifier)
            trashedPhotoIDs.remove(photo.asset.localIdentifier)
            persistFlags()
            updateDisplayPhotos()
        }
    }
    
    /// Unmark a photo as reviewed (for undo functionality)
    func unmarkReviewed(_ photo: Photo) {
        if let index = allPhotos.firstIndex(where: { $0.id == photo.id }) {
            allPhotos[index].isReviewed = false
            reviewedPhotoIDs.remove(photo.asset.localIdentifier)
            persistFlags()
            updateDisplayPhotos()
        }
    }
    
    // MARK: - Story Interaction Tracking
    
    /// Mark a photo interaction within a story without affecting its reviewed status
    func markStoryInteraction(_ photo: Photo, interaction: String) {
        if let index = allPhotos.firstIndex(where: { $0.id == photo.id }) {
            allPhotos[index].storyInteraction = interaction
            print("📖 Story interaction tracked: \(interaction) for photo \(photo.asset.localIdentifier)")
        }
    }
    
    /// Complete a story series - mark all interacted photos as reviewed and move story to end
    func completeStorySeries(_ seriesId: UUID) {
        // Find the series
        guard let seriesIndex = photoSeries.firstIndex(where: { $0.id == seriesId }) else {
            print("⚠️ Could not find series to complete: \(seriesId)")
            return
        }
        
        let series = photoSeries[seriesIndex]
        print("✅ Completing story series: \(series.title)")
        
        // Mark all interacted photos in the series as reviewed
        var photosMarkedReviewed = 0
        for photo in series.photos {
            if let photoIndex = allPhotos.firstIndex(where: { $0.id == photo.id }) {
                let photoData = allPhotos[photoIndex]
                if photoData.storyInteraction == "keep" {
                    allPhotos[photoIndex].isReviewed = true
                    reviewedPhotoIDs.insert(photo.asset.localIdentifier)
                    photosMarkedReviewed += 1
                }
                // Trash interactions are already handled
                // Clear story interaction since it's now processed
                allPhotos[photoIndex].storyInteraction = nil
            }
        }
        
        // Mark series as completed (ordering will be handled by orderedPhotoSeries computed property)
        photoSeries[seriesIndex].isCompleted = true
        photoSeries[seriesIndex].completedAt = Date()
        photoSeries[seriesIndex].isViewed = true
        
        // Persist changes and update display
        persistFlags()
        updateDisplayPhotos()
        
        print("✅ Story series completed. Marked \(photosMarkedReviewed) photos as reviewed. Moved series to end.")
    }
    
    /// Clear story interactions for a series (when user exits without completing)
    func clearStoryInteractions(for seriesId: UUID) {
        guard let series = photoSeries.first(where: { $0.id == seriesId }) else { return }
        
        for photo in series.photos {
            if let index = allPhotos.firstIndex(where: { $0.id == photo.id }) {
                allPhotos[index].storyInteraction = nil
            }
        }
        print("🧹 Cleared story interactions for series: \(series.title)")
    }
    
    /// Non-mutating helper that performs the same logic as the old `detectPhotoSeries()` but
    /// returns the result instead of touching @Published state. Runs on a background queue.
    /// Now works on ALL non-trashed photos to ensure series integrity regardless of reviewed status.
    private func calculateSeries(from sourcePhotos: [Photo]) -> [PhotoSeriesData] {
        // Use ALL non-trashed photos for series detection, not just non-reviewed ones
        // This ensures series integrity is maintained even when individual photos are reviewed
        let allNonTrashedPhotos = allPhotos.filter { !$0.isTrashed }
        let cameraPhotos = allNonTrashedPhotos.filter { isCameraPhoto($0.asset) }
        
        guard !cameraPhotos.isEmpty else { return [] }

        var seriesResult: [PhotoSeriesData] = []
        var currentSeries: [Photo] = []
        let minSeriesSize = 3

        for (index, photo) in cameraPhotos.enumerated() {
            if currentSeries.isEmpty {
                currentSeries.append(photo)
            } else {
                let lastPhoto = currentSeries.last!
                let delta = abs(photo.creationDate.timeIntervalSince(lastPhoto.creationDate))
                if delta <= nonSeriesTimeThreshold {
                    currentSeries.append(photo)
                } else {
                    if currentSeries.count >= minSeriesSize {
                        let seriesData = PhotoSeriesData(
                            photos: currentSeries,
                            thumbnailPhoto: currentSeries.first!,
                            title: getTitleForSeries(currentSeries)
                        )
                        seriesResult.append(seriesData)
                    }
                    currentSeries = [photo]
                }
            }

            // Last element handling
            if index == cameraPhotos.count - 1 && currentSeries.count >= minSeriesSize {
                let seriesData = PhotoSeriesData(
                    photos: currentSeries,
                    thumbnailPhoto: currentSeries.first!,
                    title: getTitleForSeries(currentSeries)
                )
                seriesResult.append(seriesData)
            }
        }

        // Sort newest first and keep max 15 to stay in line with previous behaviour
        seriesResult.sort { ($0.photos.first?.creationDate ?? Date()) > ($1.photos.first?.creationDate ?? Date()) }
        return Array(seriesResult.prefix(15))
    }
    
    /// Prefetch thumbnails for the given photos to make UI swipes feel instant. The caching manager keeps
    /// them in memory until we explicitly stop or the system purges the cache. This is lightweight because
    /// we are only asking for small images.
    /// - Parameters:
    ///   - photos: List of photos to pre-cache. Provide **only a handful** (e.g. next 3–5) to avoid RAM spikes.
    ///   - targetSize: Pixel size you expect to show. Defaults to `defaultThumbnailSize`.
    func prefetchThumbnails(for photos: [Photo], targetSize: CGSize = PhotoManager.defaultThumbnailSize) {
        let assets = photos.map { $0.asset }
        guard !assets.isEmpty else { return }

        #if DEBUG
        let ids = assets.prefix(1).map { $0.localIdentifier.suffix(8) }.joined(separator: ", ")
        print("🗂️ Prefetching \(assets.count) thumbnails: [\(ids)...] – size: \(targetSize)")
        #endif

        // Convert logical points to pixels if caller passed point size (typically < 500 pt)
        let scale = UIScreen.main.scale
        let pixelTargetSize: CGSize = targetSize.width < 500 ? CGSize(width: targetSize.width * scale, height: targetSize.height * scale) : targetSize

        // Use a more conservative approach - only cache one at a time for home view
        let limitedAssets = Array(assets.prefix(1))

        let opts = PHImageRequestOptions()
        opts.deliveryMode = .fastFormat
        opts.resizeMode = .fast
        opts.isSynchronous = false

        #if DEBUG
        print("🗂️→ PHCachingImageManager startCachingImages pixelSize=\(pixelTargetSize) (from targetSize=\(targetSize)) for asset=\(assets.first?.localIdentifier.suffix(8) ?? "-")")
        #endif

        imageManager.startCachingImages(
            for: limitedAssets,
            targetSize: pixelTargetSize,
            contentMode: .aspectFill,
            options: opts
        )
    }

    /// Stop caching thumbnails for the provided photos. Call this when you are sure those photos are not going
    /// to be displayed soon (e.g. they were removed from the current feed).
    func stopPrefetchingThumbnails(for photos: [Photo], targetSize: CGSize = PhotoManager.defaultThumbnailSize) {
        let assets = photos.map { $0.asset }
        guard !assets.isEmpty else { return }
        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }
    
    /// Clear all caches when memory pressure occurs
    func clearImageCaches() {
        imageManager.stopCachingImagesForAllAssets()
        // Also clear the PhotoImageView cache
        // We'll need to add a notification for this
        NotificationCenter.default.post(name: NSNotification.Name("ClearImageCache"), object: nil)
    }
    
    /// Clear old cached images selectively to maintain performance
    func clearOldCaches() {
        // Only clear caches for photos not in current display set
        let currentPhotoIds = Set(displayPhotos.prefix(50).map { $0.asset.localIdentifier })
        let seriesPhotoIds = Set(photoSeries.flatMap { $0.photos.prefix(10).map { $0.asset.localIdentifier } })
        let keepIds = currentPhotoIds.union(seriesPhotoIds)
        
        // Notify image loaders to clear non-essential caches
        NotificationCenter.default.post(
            name: NSNotification.Name("ClearOldImageCache"), 
            object: nil, 
            userInfo: ["keepIds": keepIds]
        )
        
        // Also clear some PHCachingImageManager caches but keep current photos
        let assetsToKeep = displayPhotos.prefix(20).map { $0.asset }
        imageManager.stopCachingImagesForAllAssets()
        
        // Re-cache only the most essential images
        if !assetsToKeep.isEmpty {
            imageManager.startCachingImages(
                for: assetsToKeep,
                targetSize: PhotoManager.defaultThumbnailSize,
                contentMode: .aspectFill,
                options: nil
            )
        }
    }

    // MARK: - Feed / Display helpers
    /// Re-calculate the derived collections (displayPhotos, trashedPhotos, photoSeries) on a background queue,
    /// then publish the results on the main queue to keep the UI responsive.
    private func updateDisplayPhotos() {
        processingQueue.async { [weak self] in
            guard let self else { return }
            let newDisplay = self.allPhotos.filter { !$0.isTrashed && !$0.isReviewed }
            let newTrash = self.allPhotos.filter { $0.isTrashed }
            // Series detection now works on all non-trashed photos to maintain integrity
            let newSeries = self.calculateSeries(from: []) // Parameter ignored, uses allPhotos internally

            DispatchQueue.main.async {
                // Order newest first to match Photos behaviour
                self.displayPhotos = newDisplay.sorted { $0.creationDate > $1.creationDate }
                // Sort trash by most recently added to trash first
                self.trashedPhotos = newTrash.sorted { ($0.dateMovedToTrash ?? Date.distantPast) > ($1.dateMovedToTrash ?? Date.distantPast) }
                self.photoSeries = newSeries
            }
        }
    }
    
    /// Get photos that are NOT part of any series - these should appear in the main feed
    /// Excludes favorited photos as they are already curated content
    /// Now correctly excludes ALL series photos regardless of their reviewed status
    var nonSeriesPhotos: [Photo] {
        let seriesPhotoIds = Set(photoSeries.flatMap { $0.photos.map { $0.id } })
        return displayPhotos.filter { !seriesPhotoIds.contains($0.id) && !$0.isFavorite }
    }
    
    /// Get properly ordered photo series - unviewed first, then viewed, completed at the end
    var orderedPhotoSeries: [PhotoSeriesData] {
        let unviewed = photoSeries.filter { !$0.isViewed && !$0.isCompleted }
        let viewed = photoSeries.filter { $0.isViewed && !$0.isCompleted }
        let completed = photoSeries.filter { $0.isCompleted }
        
        // Sort each group by creation date (newest first)
        let sortedUnviewed = unviewed.sorted { ($0.photos.first?.creationDate ?? Date()) > ($1.photos.first?.creationDate ?? Date()) }
        let sortedViewed = viewed.sorted { ($0.photos.first?.creationDate ?? Date()) > ($1.photos.first?.creationDate ?? Date()) }
        let sortedCompleted = completed.sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
        
        return sortedUnviewed + sortedViewed + sortedCompleted
    }

    /// Determine whether the given asset originated from the system camera (as opposed to e.g. screenshots, WhatsApp, etc.)
    private func isCameraPhoto(_ asset: PHAsset) -> Bool {
        // Exclude screenshots first – they have a dedicated subtype flag.
        if asset.mediaSubtypes.contains(.photoScreenshot) { return false }
        // The user-library source type generally corresponds to pictures captured by the device camera or imported manually.
        // This heuristic is good enough for our simple series-detection logic.
        return asset.sourceType.contains(.typeUserLibrary)
    }

    // MARK: - Quick Statistics Helpers
    /// Total number of photos currently visible in the main feed (excluding trashed & reviewed).
    var totalPhotosCount: Int {
        displayPhotos.count
    }

    /// Number of photos added in the last 7 days (based on creation date).
    var photosLastWeek: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return displayPhotos.filter { $0.creationDate >= oneWeekAgo }.count
    }

    /// Total number of photos the user has interacted with (trashed or reviewed)
    var processedPhotosCount: Int {
        allPhotos.filter { $0.isTrashed || $0.isReviewed }.count
    }

    // MARK: - Persistence Helpers
    private func loadPersistedFlags() {
        if let reviewedArray = defaults.array(forKey: reviewedKey) as? [String] {
            reviewedPhotoIDs = Set(reviewedArray)
        }
        if let trashedArray = defaults.array(forKey: trashedKey) as? [String] {
            trashedPhotoIDs = Set(trashedArray)
        }
    }

    private func persistFlags() {
        defaults.set(Array(reviewedPhotoIDs), forKey: reviewedKey)
        defaults.set(Array(trashedPhotoIDs), forKey: trashedKey)
    }

    func downloadPhoto(with id: String) {
        print("[Analytics] content_downloaded event sent for id: \(id)")
        Analytics.logEvent("content_downloaded", parameters: [
            "timestamp": Date().timeIntervalSince1970,
            "content_id": id
        ])
    }

    // MARK: - Authorization
    func checkPhotoLibraryAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status
        
        switch status {
        case .authorized, .limited:
            loadRandomNonSeriesPhotos() // Use new optimized loader
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    if status == .authorized || status == .limited {
                        self?.loadRandomNonSeriesPhotos() // Use new optimized loader
                    }
                }
            }
        default:
            break
        }
    }
}