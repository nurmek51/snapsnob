import SwiftUI
import Photos

/// High-performance photo loader that preloads images for instant, seamless transitions
/// Designed to eliminate all flash effects and provide Tinder-level smoothness
@MainActor
class SeamlessPhotoLoader: ObservableObject {
    @Published var currentImage: UIImage?
    @Published var isReady = false
    
    // Internal preloading system
    private var preloadedImages: [String: UIImage] = [:]
    private var loadingQueue: [String] = []
    private var currentAssetID: String?
    
    // Shared resources for performance
    private static let imageManager = PHCachingImageManager()
    private static let loadQueue = DispatchQueue(label: "seamless.photo.loader", qos: .userInitiated, attributes: .concurrent)
    
    // Memory management
    private static let maxCacheSize = 10
    private var cacheOrder: [String] = []
    
    // MARK: - Public Interface
    
    /// Load a photo instantly if preloaded, or load with high priority
    func loadPhoto(_ photo: Photo, targetSize: CGSize) {
        let assetID = photo.asset.localIdentifier
        
        // Skip if already showing this photo
        guard currentAssetID != assetID else { return }
        
        currentAssetID = assetID
        
        // Check if already preloaded
        if let preloadedImage = preloadedImages[assetID] {
            // Instant display - no animation to prevent flash
            currentImage = preloadedImage
            isReady = true
            return
        }
        
        // Load with high priority for immediate display
        loadImageWithPriority(photo: photo, targetSize: targetSize, assetID: assetID)
    }
    
    /// Preload a batch of photos for instant future access
    func preloadPhotos(_ photos: [Photo], targetSize: CGSize) {
        let assetIDs = photos.map { $0.asset.localIdentifier }
        
        // Filter out already preloaded photos
        let newAssetIDs = assetIDs.filter { !preloadedImages.keys.contains($0) }
        
        // Add to loading queue
        loadingQueue.append(contentsOf: newAssetIDs)
        
        // Start background preloading
        for photo in photos.filter({ newAssetIDs.contains($0.asset.localIdentifier) }) {
            preloadImageInBackground(photo: photo, targetSize: targetSize)
        }
    }
    
    /// Clear cache to manage memory
    func clearCache() {
        preloadedImages.removeAll()
        cacheOrder.removeAll()
        loadingQueue.removeAll()
        print("🧹 SeamlessPhotoLoader: Cache cleared")
    }
    
    // MARK: - Private Implementation
    
    private func loadImageWithPriority(photo: Photo, targetSize: CGSize, assetID: String) {
        // Calculate retina-aware size
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(
            width: targetSize.width * scale,
            height: targetSize.height * scale
        )
        
        // High-priority loading options for immediate display
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic // Get best available immediately
        options.resizeMode = .exact
        options.isSynchronous = false
        
        Self.imageManager.requestImage(
            for: photo.asset,
            targetSize: pixelSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, info in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Only update if this is still the current request
                guard self.currentAssetID == assetID else { return }
                
                if let image = image {
                    self.currentImage = image
                    self.isReady = true
                    
                    // Cache for future use
                    self.storeInCache(assetID: assetID, image: image)
                }
            }
        }
    }
    
    private func preloadImageInBackground(photo: Photo, targetSize: CGSize) {
        let assetID = photo.asset.localIdentifier
        
        Self.loadQueue.async { [weak self] in
            guard let self = self else { return }
            
            let scale = UIScreen.main.scale
            let pixelSize = CGSize(
                width: targetSize.width * scale,
                height: targetSize.height * scale
            )
            
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isSynchronous = false
            
            Self.imageManager.requestImage(
                for: photo.asset,
                targetSize: pixelSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, info in
                guard let self = self, let image = image else { return }
                
                Task { @MainActor in
                    self.storeInCache(assetID: assetID, image: image)
                }
            }
        }
    }
    
    private func storeInCache(assetID: String, image: UIImage) {
        // Manage cache size
        if preloadedImages.count >= Self.maxCacheSize {
            // Remove oldest cached image
            if let oldestAssetID = cacheOrder.first {
                preloadedImages.removeValue(forKey: oldestAssetID)
                cacheOrder.removeFirst()
            }
        }
        
        // Store new image
        preloadedImages[assetID] = image
        cacheOrder.append(assetID)
        
        print("📸 SeamlessPhotoLoader: Cached image for \(assetID.suffix(8)), cache size: \(preloadedImages.count)")
    }
}

/// Ultra-optimized photo view that works with SeamlessPhotoLoader for instant display
struct SeamlessPhotoView: View {
    let photo: Photo
    let targetSize: CGSize
    @StateObject private var loader = SeamlessPhotoLoader()
    
    var body: some View {
        Group {
            if let image = loader.currentImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: targetSize.width, height: targetSize.height)
                    .clipped()
            } else {
                // Minimal loading placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: targetSize.width, height: targetSize.height)
            }
        }
        .onAppear {
            loader.loadPhoto(photo, targetSize: targetSize)
        }
        .onChange(of: photo.id) { _, _ in
            loader.loadPhoto(photo, targetSize: targetSize)
        }
    }
} 