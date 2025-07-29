import SwiftUI
import Photos
import AVKit
import AVFoundation

class SeamlessVideoLoader: ObservableObject {
    @Published var currentThumbnail: UIImage?
    @Published var currentPlayer: AVPlayer?
    @Published var isReady = false
    
    private var currentAssetID: String?
    private var preloadedThumbnails: [String: UIImage] = [:]
    private var preloadedPlayers: [String: AVPlayer] = [:]
    private var loadingQueue: [String] = []
    
    private static let imageManager = PHCachingImageManager()
    private static let loadQueue = DispatchQueue(label: "seamless.video.loader", qos: .userInitiated, attributes: .concurrent)

    private static let maxCacheSize = 8  // Increased cache size for better preloading
    private var cacheOrder: [String] = []

    func loadVideo(_ video: Video, targetSize: CGSize) {
        let assetID = video.asset.localIdentifier
        if currentAssetID == assetID && isReady { 
            print("🎬 Video already loaded: \(assetID.prefix(8))")
            return 
        }
        
        print("🎬 Loading video: \(assetID.prefix(8))")
        currentAssetID = assetID
        isReady = false

        if let preloadedThumbnail = preloadedThumbnails[assetID], let preloadedPlayer = preloadedPlayers[assetID] {
            print("🎬 Using preloaded content for: \(assetID.prefix(8))")
            currentThumbnail = preloadedThumbnail
            currentPlayer = preloadedPlayer
            isReady = true
            return
        }

        // Load thumbnail and player in parallel for faster loading
        loadThumbnailWithPriority(video: video, targetSize: targetSize, assetID: assetID)
        loadPlayerWithPriority(video: video, assetID: assetID)
    }

    func preloadVideos(_ videos: [Video], targetSize: CGSize) {
        let assetIDs = videos.map { $0.asset.localIdentifier }
        let newAssetIDs = assetIDs.filter { !preloadedThumbnails.keys.contains($0) && !preloadedPlayers.keys.contains($0) }
        loadingQueue.append(contentsOf: newAssetIDs)
        
        print("🎬 Preloading \(newAssetIDs.count) new videos")
        
        for video in videos.filter({ newAssetIDs.contains($0.asset.localIdentifier) }) {
            preloadThumbnailInBackground(video: video, targetSize: targetSize)
            preloadPlayerInBackground(video: video)
        }
    }

    func clearCache() {
        print("🎬 Clearing video cache")
        preloadedThumbnails.removeAll()
        preloadedPlayers.removeAll()
        cacheOrder.removeAll()
        loadingQueue.removeAll()
    }

    private func loadThumbnailWithPriority(video: Video, targetSize: CGSize, assetID: String) {
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        options.isSynchronous = false

        Self.imageManager.requestImage(for: video.asset, targetSize: pixelSize, contentMode: .aspectFill, options: options) { [weak self] image, info in
            guard let self = self, self.currentAssetID == assetID, let image = image else { return }
            DispatchQueue.main.async {
                self.currentThumbnail = image
                self.storeInCache(assetID: assetID, thumbnail: image, player: nil)
            }
        }
    }

    private func loadPlayerWithPriority(video: Video, assetID: String) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        options.version = .current
        
        Self.imageManager.requestAVAsset(forVideo: video.asset, options: options) { [weak self] avAsset, audioMix, info in
            guard let self = self, let avAsset = avAsset else { return }
            
            let playerItem = AVPlayerItem(asset: avAsset)
            let player = AVPlayer(playerItem: playerItem)
            player.isMuted = true
            
            DispatchQueue.main.async {
                if self.currentAssetID == assetID {
                    self.currentPlayer = player
                    self.isReady = true
                }
                self.storeInCache(assetID: assetID, thumbnail: nil, player: player)
            }
        }
    }
    
    private func preloadThumbnailInBackground(video: Video, targetSize: CGSize) {
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        options.isSynchronous = false
        
        Self.imageManager.requestImage(for: video.asset, targetSize: pixelSize, contentMode: .aspectFill, options: options) { [weak self] image, info in
            guard let self = self, let image = image else { return }
            DispatchQueue.main.async {
                self.storeInCache(assetID: video.asset.localIdentifier, thumbnail: image, player: nil)
            }
        }
    }
    
    private func preloadPlayerInBackground(video: Video) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        options.version = .current
        
        Self.imageManager.requestAVAsset(forVideo: video.asset, options: options) { [weak self] avAsset, audioMix, info in
            guard let self = self, let avAsset = avAsset else { return }
            
            let playerItem = AVPlayerItem(asset: avAsset)
            let player = AVPlayer(playerItem: playerItem)
            player.isMuted = true
            
            DispatchQueue.main.async {
                self.storeInCache(assetID: video.asset.localIdentifier, thumbnail: nil, player: player)
            }
        }
    }
    
    private func storeInCache(assetID: String, thumbnail: UIImage?, player: AVPlayer?) {
        if let thumbnail = thumbnail {
            preloadedThumbnails[assetID] = thumbnail
        }
        if let player = player {
            preloadedPlayers[assetID] = player
        }
        
        if !cacheOrder.contains(assetID) {
            cacheOrder.append(assetID)
        }
        
        // Maintain cache size
        while cacheOrder.count > Self.maxCacheSize {
            let oldestAssetID = cacheOrder.removeFirst()
            preloadedThumbnails.removeValue(forKey: oldestAssetID)
            preloadedPlayers.removeValue(forKey: oldestAssetID)
        }
    }
}

struct SeamlessVideoView: View {
    let video: Video
    let targetSize: CGSize
    let autoPlay: Bool
    @StateObject private var loader = SeamlessVideoLoader()
    @State private var isPlayerReady = false
    @State private var showThumbnail = true

    var body: some View {
        ZStack {
            // Always show background placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: targetSize.width, height: targetSize.height)
            
            // Show thumbnail while video is loading or when not playing
            if let thumbnail = loader.currentThumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: targetSize.width, height: targetSize.height)
                    .clipped()
                    .opacity(showThumbnail ? 1.0 : 0.2)  // Keep thumbnail visible but faded when video plays
                    .animation(.easeInOut(duration: 0.4), value: showThumbnail)
            }

            // Video player overlay
            if let player = loader.currentPlayer {
                VideoPlayer(player: player)
                    .frame(width: targetSize.width, height: targetSize.height)
                    .opacity(isPlayerReady ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: isPlayerReady)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isPlayerReady = true
                            if autoPlay {
                                showThumbnail = false
                                print("▶️ Auto-playing video: \(video.id.uuidString.prefix(8))")
                                player.play()
                            } else {
                                print("⏸️ Video ready but autoPlay is false: \(video.id.uuidString.prefix(8))")
                            }
                        }
                    }
                    .onDisappear {
                        isPlayerReady = false
                        showThumbnail = true
                        print("⏸️ Stopping video: \(video.id.uuidString.prefix(8))")
                        player.pause()
                        player.seek(to: .zero)  // Reset video position
                    }
            }
        }
        .onAppear {
            showThumbnail = true
            print("🎬 SeamlessVideoView onAppear for video: \(video.id.uuidString.prefix(8))")
            loader.loadVideo(video, targetSize: targetSize)
        }
        .onChange(of: autoPlay) { _, shouldPlay in
            print("🎬 AutoPlay changed to: \(shouldPlay) for video: \(video.id.uuidString.prefix(8))")
            if let player = loader.currentPlayer {
                if shouldPlay && isPlayerReady {
                    showThumbnail = false
                    print("▶️ Playing video: \(video.id.uuidString.prefix(8))")
                    player.play()
                } else {
                    showThumbnail = true
                    print("⏸️ Pausing video: \(video.id.uuidString.prefix(8))")
                    player.pause()
                }
            } else {
                print("⚠️ Player not ready yet for video: \(video.id.uuidString.prefix(8))")
            }
        }
        .onChange(of: video.id) { _, newVideoId in
            // Reset states when video changes
            isPlayerReady = false
            showThumbnail = true
            print("🔄 Video changed to: \(newVideoId.uuidString.prefix(8))")
        }
    }
} 