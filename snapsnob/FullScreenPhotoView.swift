import SwiftUI
import Photos

struct FullScreenPhotoView: View {
    let photo: Photo
    let photoManager: PhotoManager
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var hasError = false
    @State private var dismissOffset: CGSize = .zero
    @State private var isVerticalDragActive: Bool = false
    @State private var isDragModeActive: Bool = false
    @State private var dragDirection: DragDirection? = nil
    
    enum DragDirection {
        case horizontal
        case vertical
    }
    
    /// In-memory cache for full-size images already fetched during current session.
    private static var imageCache = NSCache<NSString, UIImage>()
    
    /// Prefetch full-size images for a set of photos (no UI updates).
    static func prefetch(_ photos: [Photo]) {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isSynchronous = false

        for photo in photos {
            let key = NSString(string: photo.asset.localIdentifier)
            if FullScreenPhotoView.imageCache.object(forKey: key) != nil { continue }
            imageManager.requestImage(for: photo.asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
                if let image = image {
                    FullScreenPhotoView.imageCache.setObject(image, forKey: key)
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Dynamic overlay – starts semi-transparent and quickly becomes clear when the user begins to swipe down.
            // At 0 pt drag → 85 % black, at 120 pt → fully transparent.
            Color.black.opacity(max(0.0, 0.85 - min(abs(dismissOffset.height) / 120.0, 0.85))).ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("Загрузка изображения...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .onAppear {
                    print("🔄 FullScreen: Showing loading state")
                }
            } else if hasError {
                // Error state
                VStack(spacing: 20) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Не удалось загрузить изображение")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.headline)
                    
                    Text("Проверьте подключение к интернету")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.body)
                    
                    Button("Попробовать снова") {
                        print("🔄 Retry loading fullscreen image")
                        loadFullSizeImage()
                    }
                    .foregroundColor(.blue)
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.2))
                    )
                }
                .onAppear {
                    print("❌ FullScreen: Showing error state")
                }
            } else if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(x: offset.width, y: offset.height + dismissOffset.height)
                    .opacity(1.0 - abs(dismissOffset.height) / 300.0)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: loadedImage != nil)
                    .onAppear {
                        print("✅ FullScreen: Showing loaded image - Size: \(image.size)")
                    }
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale *= delta
                                scale = min(max(scale, 0.5), 5.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10) // Higher minimum distance for better recognition
                            .onChanged { value in
                                if scale > 1.0 {
                                    // Pan when zoomed - only allow movement
                                    let newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    offset = newOffset
                                } else {
                                    // Determine drag direction only once at the beginning of the gesture
                                    if !isDragModeActive {
                                        let horizontalDistance = abs(value.translation.width)
                                        let verticalDistance = abs(value.translation.height)
                                        
                                        // Need significant movement to determine direction
                                        if horizontalDistance > 15 || verticalDistance > 15 {
                                            isDragModeActive = true
                                            
                                            // Determine direction with hysteresis for better UX
                                            if verticalDistance > horizontalDistance * 1.5 {
                                                // Clearly vertical gesture
                                                dragDirection = .vertical
                                                isVerticalDragActive = true
                                            } else if horizontalDistance > verticalDistance * 1.5 {
                                                // Clearly horizontal gesture - let TabView handle it
                                                dragDirection = .horizontal
                                                isVerticalDragActive = false
                                            }
                                            // If ambiguous, wait for more movement
                                        }
                                    }

                                    // Only update dismiss offset for confirmed vertical gestures
                                    if dragDirection == .vertical && isVerticalDragActive {
                                        dismissOffset = CGSize(width: 0, height: value.translation.height)
                                    } else {
                                        dismissOffset = .zero
                                    }
                                }
                            }
                            .onEnded { value in
                                if scale > 1.0 {
                                    // Save pan offset when zoomed
                                    lastOffset = offset
                                } else if dragDirection == .vertical && isVerticalDragActive {
                                    // Handle dismiss gesture only for confirmed vertical drags
                                    let translation = value.translation
                                    let velocity = value.velocity
                                    let dismissThreshold: CGFloat = 150 // Increased threshold for stability
                                    let velocityThreshold: CGFloat = 1000 // Higher velocity threshold
                                    
                                    let shouldDismiss = abs(translation.height) > dismissThreshold || 
                                                      abs(velocity.height) > velocityThreshold
                                    
                                    if shouldDismiss {
                                        print("📱 Vertical swipe to dismiss detected")
                                        let finalOffset = translation.height > 0 ? 1000.0 : -1000.0
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                            dismissOffset = CGSize(width: 0, height: finalOffset)
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            onDismiss()
                                        }
                                    } else {
                                        // Cancel dismiss - return to original position
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                                            dismissOffset = .zero
                                        }
                                    }
                                }
                                
                                // Reset drag state for next gesture
                                isDragModeActive = false
                                dragDirection = nil
                                isVerticalDragActive = false
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                                print("🔍 Zoom reset to 100%")
                            } else {
                                scale = 2.0
                                print("🔍 Zoomed to 200%")
                            }
                        }
                    }
            } else {
                // Fallback for unexpected state
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Неизвестная ошибка")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.headline)
                    
                    Text("Debug: isLoading=\(isLoading), hasError=\(hasError), loadedImage=\(loadedImage != nil)")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                    
                    Button("Закрыть") {
                        print("❌ Closing due to unknown error")
                        onDismiss()
                    }
                    .foregroundColor(.blue)
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.2))
                    )
                }
                .onAppear {
                    print("❓ FullScreen: Showing unknown state - isLoading: \(isLoading), hasError: \(hasError), loadedImage: \(loadedImage != nil)")
                }
            }
            
            // Navigation Controls
            VStack {
                HStack {
                    // Back button
                
                    
                    Spacer()
                    
                    // Close button
                    Button(action: {
                        print("❌ Close button pressed in full screen")
                        onDismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .opacity(1.0 - abs(dismissOffset.height) / 200.0) // Hide controls during dismiss
                
                Spacer()
                
                // Zoom indicator and instructions
                VStack(spacing: 8) {
                    if scale != 1.0 {
                        HStack {
                            Spacer()
                            Text("\(Int(scale * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.6))
                                        .background(
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                        )
                                )
                        }
                    }
                    
                    if scale == 1.0 && !isLoading && !hasError {
                        HStack {
                            Spacer()
                            Text("Потяните вниз для закрытия")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.4))
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .opacity(1.0 - abs(dismissOffset.height) / 200.0) // Hide during dismiss
            }
        }
        // Navigation and status bar handling is done at the gallery level to avoid repeated hide/show animations when paging
        .background(Color.clear) // ensure hosting controller view is transparent
        .onAppear {
            print("🖼️ FullScreenPhotoView appeared for asset: \(photo.asset.localIdentifier)")
            print("🔍 Initial state - isLoading: \(isLoading), hasError: \(hasError), loadedImage: \(loadedImage != nil)")
            loadFullSizeImage()
        }
        .onDisappear {
            print("🖼️ FullScreenPhotoView disappeared")
        }
    }
    
    private func loadFullSizeImage() {
        print("🖼️ Loading full size image for asset: \(photo.asset.localIdentifier)")
        print("🔍 Setting states - isLoading: true, hasError: false, loadedImage: nil")
        
        // Check cache first to avoid reloads when the user is simply paging.
        let cacheKey = NSString(string: photo.asset.localIdentifier)
        if let cached = FullScreenPhotoView.imageCache.object(forKey: cacheKey) {
            print("⚡️ Using cached fullscreen image")
            self.loadedImage = cached
            self.isLoading = false
            self.hasError = false
            return
        }
        
        DispatchQueue.main.async {
            isLoading = true
            hasError = false
            loadedImage = nil
        }
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        
        // Add progress handler for better UX
        options.progressHandler = { progress, error, stop, info in
            DispatchQueue.main.async {
                print("🖼️ Fullscreen image loading progress: \(progress)")
                if let error = error {
                    print("❌ Fullscreen image loading error: \(error.localizedDescription)")
                }
            }
        }
        
        let imageManager = PHImageManager.default()
        
        print("🔄 Starting PHImageManager.requestImage...")
        imageManager.requestImage(
            for: photo.asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            DispatchQueue.main.async {
                print("📤 PHImageManager callback received")
                print("🔍 Callback - image: \(image != nil), info: \(String(describing: info))")
                
                isLoading = false
                
                if let error = info?[PHImageErrorKey] as? Error {
                    print("❌ Fullscreen image loading failed: \(error.localizedDescription)")
                    hasError = true
                    return
                }
                
                if let image = image {
                    print("✅ Fullscreen image loaded successfully - Size: \(image.size)")
                    loadedImage = image
                    hasError = false
                    print("🔍 States after success - isLoading: \(isLoading), hasError: \(hasError), loadedImage: \(loadedImage != nil)")
                    // Store in cache for future swipes
                    FullScreenPhotoView.imageCache.setObject(image, forKey: cacheKey)
                } else {
                    print("⚠️ Fullscreen image loading returned nil")
                    hasError = true
                    print("🔍 States after nil - isLoading: \(isLoading), hasError: \(hasError), loadedImage: \(loadedImage != nil)")
                }
            }
        }
    }
}

#Preview {
    FullScreenPhotoView(photo: Photo(asset: PHAsset(), dateAdded: Date()), photoManager: PhotoManager()) {
        // Dismiss action
    }
}
