import SwiftUI
import Photos
import PhotosUI
import Foundation
import FirebaseAnalytics

// MARK: - Video Category
enum VideoCategory: String, CaseIterable, Codable, Identifiable {
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
        case .nature: return "videoCategory.nature".localized
        case .people: return "videoCategory.people".localized
        case .food: return "videoCategory.food".localized
        case .animals: return "videoCategory.animals".localized
        case .architecture: return "videoCategory.buildings".localized
        case .transport: return "videoCategory.vehicles".localized
        case .technology: return "videoCategory.objects".localized
        case .art: return "videoCategory.objects".localized
        case .events: return "videoCategory.people".localized
        case .sports: return "videoCategory.objects".localized
        case .travel: return "videoCategory.landscapes".localized
        case .home: return "videoCategory.objects".localized
        case .work: return "videoCategory.documents".localized
        case .shopping: return "videoCategory.objects".localized
        case .entertainment: return "videoCategory.objects".localized
        case .other: return "videoCategory.other".localized
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
        case .entertainment: return "gamecontroller.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Video Model
struct Video: Identifiable, Hashable {
    let id = UUID()
    let asset: PHAsset
    var isTrashed: Bool = false
    var category: VideoCategory?
    var qualityScore: Double = 0.0
    var dateAdded: Date
    var dateMovedToTrash: Date? = nil
    var features: [Float]? // Feature embeddings for duplicate/series detection
    var categoryConfidence: Float = 0.0
    var isFavorite: Bool = false
    var isReviewed: Bool = false
    var isSuperStar: Bool = false
    var storyInteraction: String? = nil
    
    var creationDate: Date {
        asset.creationDate ?? Date()
    }
    
    var assetIdentifier: String {
        asset.localIdentifier
    }
    
    var duration: TimeInterval {
        asset.duration
    }
    
    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Video, rhs: Video) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Enable cross-concurrency transfer
extension Video: @unchecked Sendable {}

// MARK: - Video Action
enum VideoAction {
    case keep
    case trash
    case favorite
    case superStar
}

// MARK: - Video Manager
@MainActor
class VideoManager: ObservableObject {
    @Published var videos: [Video] = []
    @Published var videoSeries: [[Video]] = []
    @Published var nonSeriesVideos: [Video] = []
    @Published var isLoading = false
    @Published var hasPermission = false
    
    private let photoLibrary = PHPhotoLibrary.shared()
    
    init() {
        checkPermission()
    }
    
    // MARK: - Permission Handling
    func checkPermission() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            hasPermission = true
            loadVideos()
        case .denied, .restricted:
            hasPermission = false
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    self?.hasPermission = status == .authorized || status == .limited
                    if self?.hasPermission == true {
                        self?.loadVideos()
                    }
                }
            }
        @unknown default:
            hasPermission = false
        }
    }
    
    // MARK: - Video Loading
    private func loadVideos() {
        isLoading = true
        print("🎬 Starting to load videos from photo library")
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        print("🎬 Found \(fetchResult.count) videos in photo library")
        
        var loadedVideos: [Video] = []
        
        fetchResult.enumerateObjects { [weak self] asset, index, stop in
            let video = Video(
                asset: asset,
                dateAdded: asset.creationDate ?? Date()
            )
            loadedVideos.append(video)
        }
        
        print("🎬 Loaded \(loadedVideos.count) video objects")
        self.videos = loadedVideos
        self.processVideos()
        self.isLoading = false
        print("🎬 Video loading completed")
    }
    
    // MARK: - Video Processing
    private func processVideos() {
        // Group videos by creation date (within 1 hour) to identify series
        var seriesGroups: [[Video]] = []
        var currentSeries: [Video] = []
        
        for video in videos {
            if let lastVideo = currentSeries.last {
                let timeDifference = abs(video.creationDate.timeIntervalSince(lastVideo.creationDate))
                if timeDifference <= 3600 { // 1 hour
                    currentSeries.append(video)
                } else {
                    if currentSeries.count > 1 {
                        seriesGroups.append(currentSeries)
                    } else if !currentSeries.isEmpty {
                        nonSeriesVideos.append(currentSeries[0])
                    }
                    currentSeries = [video]
                }
            } else {
                currentSeries = [video]
            }
        }
        
        // Handle the last series
        if currentSeries.count > 1 {
            seriesGroups.append(currentSeries)
        } else if !currentSeries.isEmpty {
            nonSeriesVideos.append(currentSeries[0])
        }
        
        self.videoSeries = seriesGroups
    }
    
    // MARK: - Video Actions
    func performAction(_ action: VideoAction, on video: Video) {
        guard let index = videos.firstIndex(where: { $0.id == video.id }) else { 
            print("❌ Video not found for action: \(action)")
            return 
        }
        
        var updatedVideo = video
        
        switch action {
        case .keep:
            updatedVideo.isReviewed = true
            print("✅ Video marked as reviewed: \(video.id)")
        case .trash:
            updatedVideo.isTrashed = true
            updatedVideo.dateMovedToTrash = Date()
            print("🗑️ Video moved to trash: \(video.id)")
        case .favorite:
            updatedVideo.isFavorite.toggle()
            updatedVideo.isReviewed = true // Favoriting also marks as reviewed
            print("❤️ Video favorite status: \(updatedVideo.isFavorite) for \(video.id)")
        case .superStar:
            updatedVideo.isSuperStar.toggle()
            updatedVideo.isReviewed = true // SuperStar also marks as reviewed
            print("⭐ Video superstar status: \(updatedVideo.isSuperStar) for \(video.id)")
        }
        
        videos[index] = updatedVideo
        processVideos() // Re-process to update series and non-series
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    // MARK: - Video Retrieval
    func getNextVideo() -> Video? {
        let availableVideo = videos.first { video in
            !video.isReviewed && !video.isTrashed
        }
        print("🔍 Getting next video - available: \(availableVideo?.id.uuidString.prefix(8) ?? "none")")
        return availableVideo
    }
    
    func getFavoriteVideos() -> [Video] {
        let favorites = videos.filter { $0.isFavorite && !$0.isTrashed }
        print("❤️ Favorite videos count: \(favorites.count)")
        return favorites
    }
    
    func getTrashedVideos() -> [Video] {
        let trashed = videos.filter { $0.isTrashed }
        print("🗑️ Trashed videos count: \(trashed.count)")
        return trashed
    }
} 