import SwiftUI
import Photos
import AVKit
import AVFoundation
import Combine
import ObjectiveC

// MARK: - Advanced Video Transition Manager
/// High-performance video transition system with TikTok-like seamless playback
/// Implements triple-buffer video architecture for zero-flash transitions
class AdvancedVideoTransitionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var currentVideo: Video?
    @Published private(set) var isTransitioning = false
    @Published private(set) var isReady = false
    
    // MARK: - Video Layer Management
    private struct VideoLayer {
        let video: Video
        let player: AVPlayer
        let thumbnail: UIImage?
        var isPreloaded: Bool = false
        var isPrimary: Bool = false
    }
    
    // Triple buffer system: Current, Next, Previous
    private var primaryLayer: VideoLayer?
    private var secondaryLayer: VideoLayer?
    private var tertiaryLayer: VideoLayer?
    
    // MARK: - Queue Management
    private var videoQueue: [Video] = []
    private var processedVideos: Set<UUID> = []
    private var preloadingVideos: Set<String> = []
    private var allAvailableVideos: [Video] = []
    private var isInfiniteMode = false
    
    // MARK: - Cache & Performance
    private let maxCacheSize = 12
    private var videoCache: [String: VideoLayer] = [:]
    private var cacheOrder: [String] = []
    
    // MARK: - Technical Infrastructure
    private static let imageManager = PHCachingImageManager()
    private let preloadQueue = DispatchQueue(label: "video.preload", qos: .userInitiated, attributes: .concurrent)
    private let transitionQueue = DispatchQueue(label: "video.transition", qos: .userInteractive)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let targetSize: CGSize
    private let preloadDepth = 3 // Number of videos to preload ahead
    
    init(targetSize: CGSize) {
        self.targetSize = targetSize
        setupImageManager()
    }
    
    // MARK: - Setup & Configuration
    private func setupImageManager() {
        Self.imageManager.allowsCachingHighQualityImages = true
        Self.imageManager.stopCachingImagesForAllAssets()
    }
    
    // MARK: - Public Interface
    func initialize(with videos: [Video]) {
        print("🎬 Initializing AdvancedVideoTransitionManager with \(videos.count) videos")
        
        // Store all available videos for infinite mode
        allAvailableVideos = videos
        isInfiniteMode = videos.count > 1
        
        // Initialize with shuffled queue
        if isInfiniteMode {
            videoQueue = generateRandomQueue()
        } else {
            videoQueue = videos.filter { !processedVideos.contains($0.id) }
        }
        
        guard let firstVideo = videoQueue.first else { 
            print("⚠️ No videos available to initialize")
            return 
        }
        
        // Set current video immediately to prevent empty state
        currentVideo = firstVideo
        print("🎬 Set initial currentVideo: \(firstVideo.id.uuidString.prefix(8))")
        
        // Load initial video with high priority
        loadInitialVideo(firstVideo) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.isReady = true
                    self?.startPreloadingPipeline()
                    print("✅ Initial video loaded successfully")
                } else {
                    print("❌ Failed to load initial video")
                }
            }
        }
    }
    
    func transitionToNext() -> Bool {
        guard !isTransitioning else {
            print("⚠️ Cannot transition: already transitioning")
            return false
        }
        
        guard let nextVideo = getNextVideo() else {
            print("⚠️ Cannot transition: no next video available")
            return false
        }
        
        executeSeamlessTransition(to: nextVideo)
        return true
    }
    
    func getCurrentPlayer() -> AVPlayer? {
        return primaryLayer?.player
    }
    
    func getCurrentThumbnail() -> UIImage? {
        return primaryLayer?.thumbnail
    }
    
    // MARK: - Feed Management
    func resetFeed() {
        print("🔄 Resetting video feed")
        processedVideos.removeAll()
        videoQueue.removeAll()
        
        if isInfiniteMode {
            videoQueue = generateRandomQueue()
            continuePreloadingPipeline()
        }
    }
    
    func hasMoreVideos() -> Bool {
        if isInfiniteMode {
            return true // Always has more in infinite mode
        }
        return !videoQueue.isEmpty
    }
    
    // MARK: - Core Video Loading
    private func loadInitialVideo(_ video: Video, completion: @escaping (Bool) -> Void) {
        let assetID = video.asset.localIdentifier
        
        // Check cache first
        if let cachedLayer = videoCache[assetID] {
            primaryLayer = cachedLayer
            primaryLayer?.isPrimary = true
            completion(true)
            return
        }
        
        loadVideoLayer(video: video, priority: .high) { [weak self] layer in
            guard let self = self, let layer = layer else {
                completion(false)
                return
            }
            
            self.primaryLayer = layer
            self.primaryLayer?.isPrimary = true
            self.cacheVideoLayer(layer, for: assetID)
            completion(true)
        }
    }
    
    private func loadVideoLayer(video: Video, priority: LoadPriority, completion: @escaping (VideoLayer?) -> Void) {
        let assetID = video.asset.localIdentifier
        
        preloadQueue.async { [weak self] in
            guard let self = self else { return }
            
            var thumbnail: UIImage?
            var player: AVPlayer?
            let loadingGroup = DispatchGroup()
            let syncQueue = DispatchQueue(label: "video.layer.sync")
            
            // Load thumbnail with synchronization
            loadingGroup.enter()
            self.loadThumbnail(for: video, priority: priority) { image in
                syncQueue.async {
                    thumbnail = image
                    loadingGroup.leave()
                }
            }
            
            // Load player with synchronization
            loadingGroup.enter()
            self.loadPlayer(for: video, priority: priority) { avPlayer in
                syncQueue.async {
                    player = avPlayer
                    loadingGroup.leave()
                }
            }
            
            loadingGroup.notify(queue: .main) {
                guard let player = player else {
                    print("❌ Failed to load video: \(assetID.prefix(8))")
                    completion(nil)
                    return
                }
                
                let layer = VideoLayer(
                    video: video,
                    player: player,
                    thumbnail: thumbnail,
                    isPreloaded: true
                )
                
                print("✅ Video layer loaded: \(assetID.prefix(8))")
                completion(layer)
            }
        }
    }
    
    // MARK: - Asset Loading
    private func loadThumbnail(for video: Video, priority: LoadPriority, completion: @escaping (UIImage?) -> Void) {
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(
            width: targetSize.width * scale,
            height: targetSize.height * scale
        )
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = priority == .high ? .highQualityFormat : .opportunistic
        options.resizeMode = .exact
        options.isSynchronous = false
        
        var hasCompleted = false
        let completionQueue = DispatchQueue(label: "thumbnail.completion")
        
        Self.imageManager.requestImage(
            for: video.asset,
            targetSize: pixelSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            completionQueue.async {
                guard !hasCompleted else { return }
                
                // Check if this is the final result
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isHighQuality = !isDegraded
                
                // For high priority requests, wait for high quality
                if priority == .high && isDegraded {
                    return // Wait for the high-quality version
                }
                
                hasCompleted = true
                completion(image)
            }
        }
    }
    
    private func loadPlayer(for video: Video, priority: LoadPriority, completion: @escaping (AVPlayer?) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = priority == .high ? .highQualityFormat : .automatic
        options.version = .current
        
        var hasCompleted = false
        let completionQueue = DispatchQueue(label: "player.completion")
        
        Self.imageManager.requestAVAsset(forVideo: video.asset, options: options) { avAsset, audioMix, info in
            completionQueue.async {
                guard !hasCompleted else { return }
                
                guard let avAsset = avAsset else {
                    hasCompleted = true
                    print("❌ Failed to get AVAsset for video: \(video.asset.localIdentifier.prefix(8))")
                    completion(nil)
                    return
                }
                
                // Check if request was cancelled or degraded
                if let info = info {
                    if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                        hasCompleted = true
                        print("❌ Video request was cancelled: \(video.asset.localIdentifier.prefix(8))")
                        completion(nil)
                        return
                    }
                    
                    if let error = info[PHImageErrorKey] as? Error {
                        hasCompleted = true
                        print("❌ Video request failed with error: \(error.localizedDescription)")
                        completion(nil)
                        return
                    }
                    
                    // Check if this is degraded and we want high quality
                    let isDegraded = (info[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if priority == .high && isDegraded {
                        return // Wait for high quality version
                    }
                }
                
                hasCompleted = true
                
                let playerItem = AVPlayerItem(asset: avAsset)
                let player = AVPlayer(playerItem: playerItem)
                
                // Optimize for seamless playback
                player.isMuted = true
                player.automaticallyWaitsToMinimizeStalling = false
                
                // Pre-buffer the video only when player is ready
                if priority == .high {
                    // Observe player status and preroll when ready
                    let statusObservation = player.observe(\.status, options: [.new]) { observedPlayer, change in
                        if observedPlayer.status == .readyToPlay {
                            observedPlayer.preroll(atRate: 1.0) { success in
                                print("🎬 Video preroll \(success ? "succeeded" : "failed"): \(video.asset.localIdentifier.prefix(8))")
                            }
                        } else if observedPlayer.status == .failed {
                            print("❌ Player failed to load: \(video.asset.localIdentifier.prefix(8))")
                            if let error = observedPlayer.error {
                                print("❌ Player error: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    // Store the observation to prevent it from being deallocated
                    objc_setAssociatedObject(player, "statusObservation", statusObservation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
                
                completion(player)
            }
        }
    }
    
    // MARK: - Seamless Transition Logic
    private func executeSeamlessTransition(to nextVideo: Video) {
        print("🎬 Executing seamless transition to: \(nextVideo.id.uuidString.prefix(8))")
        
        isTransitioning = true
        let assetID = nextVideo.asset.localIdentifier
        
        transitionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Step 1: Prepare next video layer
            if let cachedLayer = self.videoCache[assetID] {
                self.performLayerSwap(to: cachedLayer, video: nextVideo)
            } else {
                // Emergency load if not in cache
                self.loadVideoLayer(video: nextVideo, priority: .high) { [weak self] layer in
                    guard let self = self, let layer = layer else {
                        DispatchQueue.main.async {
                            self?.isTransitioning = false
                        }
                        return
                    }
                    self.performLayerSwap(to: layer, video: nextVideo)
                }
            }
        }
    }
    
    private func performLayerSwap(to newLayer: VideoLayer, video: Video) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Step 1: Pause current video
            self.primaryLayer?.player.pause()
            
            // Step 2: Atomic layer swap
            let oldPrimary = self.primaryLayer
            self.primaryLayer = newLayer
            self.primaryLayer?.isPrimary = true
            
            // Step 3: Update state
            self.currentVideo = video
            self.processedVideos.insert(video.id)
            self.removeVideoFromQueue(video)
            
            // Step 4: Start new video playback
            self.primaryLayer?.player.seek(to: .zero)
            self.primaryLayer?.player.play()
            
            // Step 5: Cleanup and reorganize layers
            self.reorganizeLayers(oldPrimary: oldPrimary)
            
            // Step 6: Continue preloading
            self.continuePreloadingPipeline()
            
            // Step 7: Complete transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isTransitioning = false
                print("✅ Seamless transition completed")
            }
        }
    }
    
    // MARK: - Layer Management
    private func reorganizeLayers(oldPrimary: VideoLayer?) {
        // Move old primary to secondary, secondary to tertiary
        tertiaryLayer = secondaryLayer
        secondaryLayer = oldPrimary
        
        // Clean up tertiary if it exists
        if let tertiary = tertiaryLayer {
            cleanupPlayer(tertiary.player)
        }
    }
    
    // MARK: - Preloading Pipeline
    private func startPreloadingPipeline() {
        print("🔄 Starting preloading pipeline")
        continuePreloadingPipeline()
    }
    
    private func continuePreloadingPipeline() {
        guard isInfiniteMode else { return } // Only preload in infinite mode
        
        let upcomingVideos = Array(videoQueue.prefix(preloadDepth))
        
        for video in upcomingVideos {
            let assetID = video.asset.localIdentifier
            
            guard !videoCache.keys.contains(assetID),
                  !preloadingVideos.contains(assetID) else { continue }
            
            preloadingVideos.insert(assetID)
            
            preloadQueue.async { [weak self] in
                self?.loadVideoLayer(video: video, priority: .medium) { [weak self] layer in
                    guard let self = self, let layer = layer else { return }
                    
                    DispatchQueue.main.async {
                        self.cacheVideoLayer(layer, for: assetID)
                        self.preloadingVideos.remove(assetID)
                        print("📥 Preloaded video: \(assetID.prefix(8))")
                    }
                }
            }
        }
    }
    
    // MARK: - Cache Management
    private func cacheVideoLayer(_ layer: VideoLayer, for assetID: String) {
        videoCache[assetID] = layer
        
        if !cacheOrder.contains(assetID) {
            cacheOrder.append(assetID)
        }
        
        // Maintain cache size
        while cacheOrder.count > maxCacheSize {
            let oldestAssetID = cacheOrder.removeFirst()
            if let oldLayer = videoCache.removeValue(forKey: oldestAssetID) {
                cleanupPlayer(oldLayer.player)
                print("🗑️ Evicted video from cache: \(oldestAssetID.prefix(8))")
            }
        }
    }
    
    // MARK: - Queue Utilities
    private func getNextVideo() -> Video? {
        // If queue is running low and we're in infinite mode, refill it
        if isInfiniteMode && videoQueue.count <= 2 {
            refillQueue()
        }
        
        return videoQueue.first
    }
    
    private func removeVideoFromQueue(_ video: Video) {
        videoQueue.removeAll { $0.id == video.id }
        print("🔄 Queue size after removal: \(videoQueue.count)")
        
        // Auto-refill if queue gets too low in infinite mode
        if isInfiniteMode && videoQueue.count <= preloadDepth {
            refillQueue()
        }
    }
    
    private func generateRandomQueue() -> [Video] {
        // Get unprocessed videos
        let unprocessedVideos = allAvailableVideos.filter { !processedVideos.contains($0.id) }
        
        // If we've processed all videos, reset processed set but keep the current video
        if unprocessedVideos.isEmpty {
            let currentVideoId = currentVideo?.id
            processedVideos.removeAll()
            if let currentId = currentVideoId {
                processedVideos.insert(currentId)
            }
            print("🔄 Reset processed videos, starting new cycle")
            return Array(allAvailableVideos.filter { $0.id != currentVideoId }.shuffled())
        }
        
        // Return shuffled unprocessed videos
        return Array(unprocessedVideos.shuffled())
    }
    
    private func refillQueue() {
        guard isInfiniteMode else { return }
        
        let newVideos = generateRandomQueue()
        let queueWasEmpty = videoQueue.isEmpty
        
        // Add new videos to queue
        videoQueue.append(contentsOf: newVideos.prefix(10)) // Add up to 10 new videos
        
        print("🔄 Refilled queue with \(newVideos.prefix(10).count) videos. Total queue: \(videoQueue.count)")
        
        // Continue preloading after refill
        if !queueWasEmpty {
            continuePreloadingPipeline()
        }
    }
    
    func updateQueue(with videos: [Video]) {
        // Update available videos
        allAvailableVideos = videos
        
        if isInfiniteMode {
            // In infinite mode, just refill the queue
            refillQueue()
        } else {
            // In single video mode, update normally
            let newVideos = videos.filter { !processedVideos.contains($0.id) }
            videoQueue = newVideos
        }
        
        continuePreloadingPipeline()
    }
    
    // MARK: - Cleanup
    func cleanup() {
        print("🧹 Cleaning up AdvancedVideoTransitionManager")
        
        // Clean up players and their observations
        cleanupPlayer(primaryLayer?.player)
        cleanupPlayer(secondaryLayer?.player)
        cleanupPlayer(tertiaryLayer?.player)
        
        for (_, layer) in videoCache {
            cleanupPlayer(layer.player)
        }
        
        videoCache.removeAll()
        cacheOrder.removeAll()
        preloadingVideos.removeAll()
        cancellables.removeAll()
        
        // Clean up feed state
        videoQueue.removeAll()
        processedVideos.removeAll()
        allAvailableVideos.removeAll()
        isInfiniteMode = false
    }
    
    private func cleanupPlayer(_ player: AVPlayer?) {
        guard let player = player else { return }
        
        player.pause()
        player.replaceCurrentItem(with: nil)
        
        // Remove status observation if it exists
        if let observation = objc_getAssociatedObject(player, "statusObservation") as? NSKeyValueObservation {
            observation.invalidate()
            objc_setAssociatedObject(player, "statusObservation", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Supporting Types
extension AdvancedVideoTransitionManager {
    enum LoadPriority {
        case high, medium, low
    }
}
