import SwiftUI
import Photos

struct PhotoImageView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let photo: Photo
    let targetSize: CGSize
    @StateObject private var imageLoader = ImageLoader()
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: targetSize.width, height: targetSize.height)
                    .opacity(imageLoader.image == nil ? 0 : 1)
            } else if imageLoader.isLoading {
                Rectangle()
                    .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                    .frame(width: targetSize.width, height: targetSize.height)
                    .overlay(
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.secondaryText(for: themeManager.isDarkMode)))
                            Text("photo.loading2".localized)
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                    )
            } else if imageLoader.hasError {
                Rectangle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: targetSize.width, height: targetSize.height)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.red)
                            Text("photo.errorLoading".localized)
                                .font(.caption)
                                .foregroundColor(.red)
                            Button("action.retry".localized) {
                                imageLoader.loadImage(from: photo.asset, targetSize: targetSize)
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)
                        }
                    )
            } else {
                Rectangle()
                    .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                    .frame(width: targetSize.width, height: targetSize.height)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            Text("photo.unavailable".localized)
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                    )
            }
        }
        .onAppear {
            imageLoader.loadImage(from: photo.asset, targetSize: targetSize)
        }
        .onChange(of: photo.asset.localIdentifier) { _, newID in
            imageLoader.cancelLoading()
            imageLoader.loadImage(from: photo.asset, targetSize: targetSize)
        }
        .onDisappear {
            imageLoader.cancelLoading()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearImageCache"))) { _ in
            ImageLoader.clearCache()
        }
    }
}

// MARK: - Image Loader
class ImageLoader: ObservableObject {
    /// Enhanced static cache with size limit and automatic cleanup
    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100 // Limit to 100 images in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
        return cache
    }()

    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var hasError = false
    private var requestID: PHImageRequestID?
    private var currentAssetID: String?
    private let imageManager = PHCachingImageManager()
    
    /// Load a thumbnail for the given asset with **retina-aware** target size so that results look crisp
    /// inside grid views on modern devices. We multiply the requested logical size by the screen scale
    /// (2×/3×) and switch to `.highQualityFormat` now that most iOS devices handle this without hitch.
    /// - Parameters:
    ///   - asset: Photos asset
    ///   - targetSize: Logical size in points that the SwiftUI view is going to occupy.
    func loadImage(from asset: PHAsset, targetSize: CGSize) {
        let assetID = asset.localIdentifier
        
        // Convert logical points to pixels to obtain a sharper thumbnail on Retina screens.
        // Detect if the caller already provided a pixel-scaled size (e.g. 330 px for 110 pt @3x) to avoid double scaling.
        let scale = UIScreen.main.scale
        let isPointSize = targetSize.width < 250 // heuristic – thumbnails & grid cells are < 250 pt.
        let pixelSize = isPointSize ? CGSize(width: targetSize.width * scale, height: targetSize.height * scale) : targetSize
        
        // Skip if we're already loading this exact asset
        if currentAssetID == assetID && (isLoading || image != nil) {
            return
        }
        
        let cacheKey = NSString(string: "\(assetID)_\(Int(pixelSize.width))x\(Int(pixelSize.height))")

        // Return cached image immediately if available
        if let cachedImage = Self.thumbnailCache.object(forKey: cacheKey) {
            #if DEBUG
            print("⚡️ Using cached thumbnail for asset: \(assetID)")
            #endif
            DispatchQueue.main.async {
                self.image = cachedImage
                self.isLoading = false
                self.hasError = false
                self.currentAssetID = assetID
            }
            return
        }

        #if DEBUG
        print("📥 ImageLoader initiate two-step request asset=\(assetID.suffix(8)) pointSize=\(targetSize) pixelSize=\(pixelSize)")
        #endif
        
        // Cancel any existing request
        cancelLoading()
        
        // Update state
        currentAssetID = assetID
        isLoading = true
        hasError = false
        
        func request(_ mode: PHImageRequestOptionsDeliveryMode) {
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.deliveryMode = mode
            opts.resizeMode = mode == .fastFormat ? .fast : .exact
            opts.isSynchronous = false

            self.requestID = imageManager.requestImage(
                for: asset,
                targetSize: pixelSize,
                contentMode: .aspectFill,
                options: opts
            ) { [weak self] image, info in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    // Only process if this is still the current asset
                    guard self.currentAssetID == assetID else { return }
                    
                    self.isLoading = false

                    #if DEBUG
                    let modeStr = mode == .fastFormat ? "FAST" : "HQ"
                    let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    print("📷 ImageLoader callback asset=\(assetID.suffix(8)) mode=\(modeStr) degraded=\(degraded) imgSize=\(image?.size ?? .zero)")
                    #endif

                    if let error = info?[PHImageErrorKey] as? NSError {
                        print("❌ Image loading failed for asset: \(assetID) - Error: \(error.localizedDescription)")

                        // Fallback for error 3303 / 3072 (resource not found / cancelled)
                        if error.domain == PHPhotosErrorDomain && (error.code == 3072 || error.code == 3303) {
                            self.retryWithImageData(asset: asset, targetSize: targetSize, assetID: assetID)
                            return
                        }

                        self.hasError = true
                        return
                    }

                    if let image = image {
                        print("✅ Image loaded successfully for asset: \(assetID) - Size: \(image.size)")
                        self.image = image
                        // Store in cache with cost based on image size
                        let cost = Int(image.size.width * image.size.height * 4)
                        Self.thumbnailCache.setObject(image, forKey: cacheKey, cost: cost)
                        self.hasError = false
                    } else {
                        // Nil image without explicit error – retry once
                        self.retryWithImageData(asset: asset, targetSize: targetSize, assetID: assetID)
                    }
                }
            }
        }

        // Quick thumbnail first
        request(.fastFormat)
        // Swap to HQ after slight delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            request(.highQualityFormat)
        }

        #if DEBUG
        print("🖼️ Two-step image request (fast+HQ) started for asset: \(assetID)")
        #endif
    }
    
    func cancelLoading() {
        if let requestID = requestID {
            #if DEBUG
            print("🚫 Cancelling image request: \(requestID)")
            #endif
            imageManager.cancelImageRequest(requestID)
            self.requestID = nil
        }
        isLoading = false
    }

    /// Fallback that loads raw image data and creates a thumbnail locally
    private func retryWithImageData(asset: PHAsset, targetSize: CGSize, assetID: String) {
        // Only retry if this is still the current asset
        guard currentAssetID == assetID else { return }
        
        #if DEBUG
        print("🔄 Retrying via requestImageDataAndOrientation for asset: \(assetID)")
        #endif
        
        let dataOpts = PHImageRequestOptions()
        dataOpts.isNetworkAccessAllowed = true
        dataOpts.isSynchronous = false

        // Compute retina-aware pixel size once for the fallback path
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)

        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: dataOpts) { [weak self] data, _, _, info in
            DispatchQueue.main.async {
                guard let self = self, self.currentAssetID == assetID else { return }
                
                if let data = data, let fullImage = UIImage(data: data) {
                    let finalImage = fullImage.preparingThumbnail(of: pixelSize) ?? fullImage
                    self.image = finalImage
                    self.hasError = false
                    
                    // Cache the result
                    let cacheKey = NSString(string: "\(assetID)_\(Int(pixelSize.width))x\(Int(pixelSize.height))")
                    let cost = Int(finalImage.size.width * finalImage.size.height * 4)
                    Self.thumbnailCache.setObject(finalImage, forKey: cacheKey, cost: cost)
                    
                    #if DEBUG
                    print("✅ Image recovered via data fallback for asset: \(assetID)")
                    #endif
                } else {
                    self.hasError = true
                    #if DEBUG
                    print("❌ Data fallback failed for asset: \(assetID)")
                    #endif
                }
            }
        }
    }
    
    /// Clear cache when memory pressure occurs
    static func clearCache() {
        thumbnailCache.removeAllObjects()
        #if DEBUG
        print("🧹 Cleared image cache due to memory pressure")
        #endif
    }
} 