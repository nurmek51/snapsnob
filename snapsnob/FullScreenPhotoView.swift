import SwiftUI
import Photos

struct FullScreenPhotoView: View {
    let photo: Photo
    let photoManager: PhotoManager
    let onDismiss: () -> Void
    
    // New properties for group navigation
    let photoGroup: [Photo]
    let groupTitle: String?
    @State private var currentIndex: Int
    
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
    
    // Navigation states
    @State private var navigationOffset: CGSize = .zero
    @State private var isNavigating = false
    @State private var nextImage: UIImage? = nil
    @State private var previousImage: UIImage? = nil
    
    // Favorite star animation states
    @State private var favoriteIconScale: CGFloat = 1.0
    @State private var favoriteIconRotation: Double = 0.0
    @State private var showFavoriteAnimation = false
    
    enum DragDirection {
        case horizontal
        case vertical
    }
    
    // Initialize with group navigation support
    init(photo: Photo, photoManager: PhotoManager, photoGroup: [Photo] = [], groupTitle: String? = nil, onDismiss: @escaping () -> Void) {
        self.photo = photo
        self.photoManager = photoManager
        self.photoGroup = photoGroup.isEmpty ? [photo] : photoGroup
        self.groupTitle = groupTitle
        self.onDismiss = onDismiss
        
        // Find the initial index of the current photo in the group
        self._currentIndex = State(initialValue: photoGroup.firstIndex(where: { $0.id == photo.id }) ?? 0)
    }
    
    private var currentPhoto: Photo {
        guard currentIndex >= 0 && currentIndex < photoGroup.count else { return photo }
        return photoGroup[currentIndex]
    }
    
    private var canNavigatePrevious: Bool {
        currentIndex > 0
    }
    
    private var canNavigateNext: Bool {
        currentIndex < photoGroup.count - 1
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
                // Main image view with navigation support
                ZStack {
                    // Current image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(x: offset.width + navigationOffset.width, y: offset.height + dismissOffset.height)
                        .opacity(1.0 - abs(dismissOffset.height) / 300.0 - abs(navigationOffset.width) / UIScreen.main.bounds.width)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: loadedImage != nil)
                    
                    // Previous image (for navigation animation)
                    if let prevImage = previousImage, navigationOffset.width > 0 {
                        Image(uiImage: prevImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .offset(x: navigationOffset.width - UIScreen.main.bounds.width, y: dismissOffset.height)
                            .opacity(navigationOffset.width / UIScreen.main.bounds.width)
                    }
                    
                    // Next image (for navigation animation)
                    if let nextImg = nextImage, navigationOffset.width < 0 {
                        Image(uiImage: nextImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .offset(x: navigationOffset.width + UIScreen.main.bounds.width, y: dismissOffset.height)
                            .opacity(-navigationOffset.width / UIScreen.main.bounds.width)
                    }
                }
                .onAppear {
                    print("✅ FullScreen: Showing loaded image - Size: \(image.size)")
                    prefetchAdjacentImages()
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
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            handleDragChanged(value)
                        }
                        .onEnded { value in
                            handleDragEnded(value)
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
                    // Group title if available
                    if let title = groupTitle {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if photoGroup.count > 1 {
                                Text("\(currentIndex + 1) из \(photoGroup.count)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                    }
                    
                    Spacer()
                    
                    // Favorite star icon
                    favoriteStarButton
                    
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
                
                // Navigation indicators and zoom info
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
                            VStack(spacing: 4) {
                                Text("Потяните вниз для закрытия")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if photoGroup.count > 1 {
                                    Text("Смахивайте влево/вправо для навигации")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
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
        .background(Color.clear)
        .onAppear {
            print("🖼️ FullScreenPhotoView appeared for asset: \(currentPhoto.asset.localIdentifier)")
            print("🔍 Initial state - isLoading: \(isLoading), hasError: \(hasError), loadedImage: \(loadedImage != nil)")
            loadFullSizeImage()
        }
        .onDisappear {
            print("🖼️ FullScreenPhotoView disappeared")
        }
        .onChange(of: currentIndex) { _, _ in
            loadFullSizeImage()
            prefetchAdjacentImages()
        }
    }
    
    // MARK: - Favorite Star Button
    
    private var favoriteStarButton: some View {
        Button(action: {
            toggleFavorite()
        }) {
            Image(systemName: currentPhoto.isFavorite ? "star.fill" : "star")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(currentPhoto.isFavorite ? .yellow : .white)
                .scaleEffect(favoriteIconScale)
                .rotationEffect(.degrees(favoriteIconRotation))
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                        )
                )
                .overlay(
                    // Glow effect for filled star
                    Circle()
                        .stroke(
                            currentPhoto.isFavorite ? Color.yellow.opacity(0.3) : Color.clear,
                            lineWidth: 2
                        )
                        .frame(width: 48, height: 48)
                        .scaleEffect(showFavoriteAnimation ? 1.2 : 1.0)
                        .opacity(showFavoriteAnimation ? 0.0 : (currentPhoto.isFavorite ? 1.0 : 0.0))
                        .animation(.easeOut(duration: 0.6), value: showFavoriteAnimation)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: favoriteIconScale)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: favoriteIconRotation)
        .animation(.easeInOut(duration: 0.3), value: currentPhoto.isFavorite)
    }
    
    // MARK: - Favorite Toggle Functionality
    
    private func toggleFavorite() {
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Play sound feedback
        SoundManager.playClick()
        
        // Start animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            favoriteIconScale = 1.3
            favoriteIconRotation += 360
        }
        
        // Show glow animation for adding to favorites
        if !currentPhoto.isFavorite {
            showFavoriteAnimation = true
            withAnimation(.easeOut(duration: 0.6)) {
                showFavoriteAnimation = false
            }
        }
        
        // Toggle favorite state
        photoManager.setFavorite(currentPhoto, isFavorite: !currentPhoto.isFavorite)
        
        // Reset scale after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                favoriteIconScale = 1.0
            }
        }
        
        print(currentPhoto.isFavorite ? "⭐ Added to favorites" : "💔 Removed from favorites")
    }
    
    // MARK: - Drag Handling
    
    private func handleDragChanged(_ value: DragGesture.Value) {
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
                        // Clearly vertical gesture - dismiss
                        dragDirection = .vertical
                        isVerticalDragActive = true
                    } else if horizontalDistance > verticalDistance * 1.5 && photoGroup.count > 1 {
                        // Clearly horizontal gesture - navigation (only if we have multiple photos)
                        dragDirection = .horizontal
                        isVerticalDragActive = false
                    }
                }
            }

            // Handle the appropriate gesture type
            if dragDirection == .vertical && isVerticalDragActive {
                dismissOffset = CGSize(width: 0, height: value.translation.height)
            } else if dragDirection == .horizontal && !isVerticalDragActive && photoGroup.count > 1 {
                navigationOffset = CGSize(width: value.translation.width, height: 0)
            } else {
                dismissOffset = .zero
                navigationOffset = .zero
            }
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        if scale > 1.0 {
            // Save pan offset when zoomed
            lastOffset = offset
        } else if dragDirection == .vertical && isVerticalDragActive {
            // Handle dismiss gesture
            let translation = value.translation
            let velocity = value.velocity
            let dismissThreshold: CGFloat = 150
            let velocityThreshold: CGFloat = 1000
            
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
                // Cancel dismiss
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                    dismissOffset = .zero
                }
            }
        } else if dragDirection == .horizontal && !isVerticalDragActive && photoGroup.count > 1 {
            // Handle navigation gesture
            let translation = value.translation
            let velocity = value.velocity
            let navigationThreshold: CGFloat = 100
            let velocityThreshold: CGFloat = 800
            
            let shouldNavigate = abs(translation.width) > navigationThreshold || 
                               abs(velocity.width) > velocityThreshold
            
            if shouldNavigate {
                if translation.width > 0 && canNavigatePrevious {
                    // Navigate to previous
                    navigateToPrevious()
                } else if translation.width < 0 && canNavigateNext {
                    // Navigate to next
                    navigateToNext()
                } else {
                    // Cancel navigation - hit boundary
                    cancelNavigation()
                }
            } else {
                // Cancel navigation
                cancelNavigation()
            }
        }
        
        // Reset drag state for next gesture
        isDragModeActive = false
        dragDirection = nil
        isVerticalDragActive = false
    }
    
    // MARK: - Navigation Methods
    
    private func navigateToPrevious() {
        guard canNavigatePrevious && !isNavigating else { return }
        
        isNavigating = true
        let targetOffset = UIScreen.main.bounds.width
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
            navigationOffset = CGSize(width: targetOffset, height: 0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentIndex -= 1
            resetNavigationState()
        }
    }
    
    private func navigateToNext() {
        guard canNavigateNext && !isNavigating else { return }
        
        isNavigating = true
        let targetOffset = -UIScreen.main.bounds.width
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
            navigationOffset = CGSize(width: targetOffset, height: 0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentIndex += 1
            resetNavigationState()
        }
    }
    
    private func cancelNavigation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
            navigationOffset = .zero
        }
    }
    
    private func resetNavigationState() {
        navigationOffset = .zero
        isNavigating = false
        previousImage = nil
        nextImage = nil
        
        // Reset zoom and pan states
        scale = 1.0
        offset = .zero
        lastOffset = .zero
    }
    
    // MARK: - Image Loading and Prefetching
    
    private func prefetchAdjacentImages() {
        // Prefetch previous image
        if canNavigatePrevious {
            let prevPhoto = photoGroup[currentIndex - 1]
            loadImageForPhoto(prevPhoto) { image in
                self.previousImage = image
            }
        }
        
        // Prefetch next image
        if canNavigateNext {
            let nextPhoto = photoGroup[currentIndex + 1]
            loadImageForPhoto(nextPhoto) { image in
                self.nextImage = image
            }
        }
    }
    
    private func loadImageForPhoto(_ photo: Photo, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = NSString(string: photo.asset.localIdentifier)
        if let cached = FullScreenPhotoView.imageCache.object(forKey: cacheKey) {
            completion(cached)
            return
        }
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        
        let imageManager = PHImageManager.default()
        imageManager.requestImage(
            for: photo.asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            DispatchQueue.main.async {
                if let image = image {
                    FullScreenPhotoView.imageCache.setObject(image, forKey: cacheKey)
                    completion(image)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    private func loadFullSizeImage() {
        print("🖼️ Loading full size image for asset: \(currentPhoto.asset.localIdentifier)")
        print("🔍 Setting states - isLoading: true, hasError: false, loadedImage: nil")
        
        // Check cache first
        let cacheKey = NSString(string: currentPhoto.asset.localIdentifier)
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
            for: currentPhoto.asset,
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
                    FullScreenPhotoView.imageCache.setObject(image, forKey: cacheKey)
                } else {
                    print("⚠️ Fullscreen image loading returned nil")
                    hasError = true
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
