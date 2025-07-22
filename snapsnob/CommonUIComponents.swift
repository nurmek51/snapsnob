import SwiftUI
import Photos

// MARK: - Common UI Components
/// This file contains reusable UI components used throughout the SnapSnob app.
/// Components are organized to promote reusability and maintain consistent UI patterns.

// MARK: - Button Styles

/// A circular button style with transparent background and glass effect
/// Used for action buttons (trash, favorite, keep) in photo cards
struct TransparentCircleButtonStyle: ButtonStyle {
    @EnvironmentObject var themeManager: ThemeManager
    /// Size of the circular button
    var size: CGFloat = 56
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            )
            // Smoother interactive spring & subtle scale
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
            // Soft glow visible only on press
            .shadow(color: AppColors.primaryText(for: themeManager.isDarkMode).opacity(configuration.isPressed ? 0.4 : 0.0),
                    radius: configuration.isPressed ? 6 : 0)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.65, blendDuration: 0.25), value: configuration.isPressed)
    }
}

// MARK: - Favorite Star Button (Reusable)

struct FavoriteStarButton: View {
    var isFavorite: Bool
    var onToggle: () -> Void
    // Animation states
    @State private var iconScale: CGFloat = 1.0
    @State private var iconRotation: Double = 0.0
    @State private var showGlow: Bool = false
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            // Sound feedback
            SoundManager.playClick()
            // Start animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                iconScale = 1.3
                iconRotation += 360
            }
            // Show glow animation for adding to favorites
            if !isFavorite {
                showGlow = true
                withAnimation(.easeOut(duration: 0.6)) {
                    showGlow = false
                }
            }
            // Toggle favorite state
            onToggle()
            // Reset scale after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    iconScale = 1.0
                }
            }
        }) {
            ZStack {
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .scaleEffect(iconScale)
                        .rotationEffect(.degrees(iconRotation))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "star")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .scaleEffect(iconScale)
                        .rotationEffect(.degrees(iconRotation))
                        .transition(.scale.combined(with: .opacity))
                }
            }
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
                Circle()
                    .stroke(
                        isFavorite ? Color.yellow.opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
                    .frame(width: 48, height: 48)
                    .scaleEffect(showGlow ? 1.2 : 1.0)
                    .opacity(showGlow ? 0.0 : (isFavorite ? 1.0 : 0.0))
                    .animation(.easeOut(duration: 0.6), value: showGlow)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: iconScale)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: iconRotation)
        .animation(.easeInOut(duration: 0.3), value: isFavorite)
    }
}

// MARK: - Story Components

/// A circular story thumbnail component with viewing state and favorite indicator
struct StoryCircle: View {
    @EnvironmentObject var themeManager: ThemeManager
    let series: PhotoSeriesData
    let photoManager: PhotoManager
    let isViewed: Bool
    let onTap: () -> Void
    
    /// Whether series contains at least one favourite photo
    private var hasFavourite: Bool {
        series.photos.contains { $0.isFavorite }
    }
    
    /// Responsive sizing for different device types
    private var circleSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 95 : 75
    }
    
    private var frameWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 100 : 78
    }
    
    var body: some View {
        VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 8 : 4) {
            Button(action: onTap) {
                // Photo fills entire outer frame with stroke overlay
                PhotoImageView(
                    photo: series.thumbnailPhoto,
                    targetSize: CGSize(width: circleSize, height: circleSize)
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            isViewed ? AppColors.secondaryText(for: themeManager.isDarkMode).opacity(0.2) : AppColors.accent(for: themeManager.isDarkMode),
                            lineWidth: UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
                        )
                )
                .shadow(color: isViewed ? .clear : .purple.opacity(0.3), radius: UIDevice.current.userInterfaceIdiom == .pad ? 8 : 6, x: 0, y: 2)
                .overlay(
                    Group {
                        if hasFavourite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.white)
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12))
                                .background(Circle().fill(Color.white).frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18,
                                                                           height: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18))
                                .clipShape(Circle())
                                .offset(x: UIDevice.current.userInterfaceIdiom == .pad ? 30 : 24, 
                                       y: UIDevice.current.userInterfaceIdiom == .pad ? 30 : 24)
                        }
                    }
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isViewed ? 0.95 : 1.0)
            
            Text(series.title)
                .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                .fontWeight(.medium)
                .foregroundColor(isViewed ? AppColors.secondaryText(for: themeManager.isDarkMode) : AppColors.primaryText(for: themeManager.isDarkMode))
                .lineLimit(1)
                .frame(width: frameWidth)
        }
    }
}

// MARK: - Photo Display Components

/// An optimized photo view that handles image loading and caching efficiently
/// This is a wrapper around PhotoImageView with enhanced preloading support
struct OptimizedPhotoView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let photo: Photo
    /// Desired logical size **in points** – will default to the view’s Geometry size if `nil`/zero.
    let targetSize: CGSize?
    @StateObject private var imageLoader = OptimizedImageLoader()
    @State private var isImageLoaded = false
    @State private var imageOpacity: Double = 0
    @State private var lastRequestedSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geo in
            let logicalSize: CGSize = {
                if let size = targetSize, size.width > 4 && size.height > 4 {
                    return size
                } else {
                    return geo.size
                }
            }()
            ZStack {
                if !isImageLoaded {
                    if let lastImage = imageLoader.image {
                        // Show a blurred version of the last loaded image as a placeholder
                        Image(uiImage: lastImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: logicalSize.width, height: logicalSize.height)
                            .clipped()
                            .blur(radius: 16)
                            .opacity(0.5)
                    } else {
                        Rectangle()
                            .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.secondaryText(for: themeManager.isDarkMode)))
                                    .scaleEffect(0.8)
                            )
                    }
                }
                if let image = imageLoader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: logicalSize.width, height: logicalSize.height)
                        .clipped()
                        .opacity(imageOpacity)
                }
            }
            .frame(width: logicalSize.width, height: logicalSize.height)
            .onAppear {
                requestImageIfNeeded(for: logicalSize)
            }
            // When loader publishes a new image, fade it in & mark as loaded
            .onChange(of: imageLoader.image) { _, newImg in
                guard newImg != nil else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    imageOpacity = 1
                    isImageLoaded = true
                }
            }
            .onChange(of: photo.id) { _, _ in
                resetAndRequest(for: logicalSize)
            }
            .onChange(of: geo.size) { _, newSize in
                requestImageIfNeeded(for: newSize)
            }
            .onDisappear {
                imageLoader.cancelLoading()
            }
        }
    }
    
    private func resetAndRequest(for size: CGSize) {
        imageOpacity = 0
        isImageLoaded = false
        lastRequestedSize = .zero // force reload
        requestImageIfNeeded(for: size)
    }
    
    private func requestImageIfNeeded(for size: CGSize) {
        guard size.width > 4, size.height > 4 else { return } // wait for real layout
        // Avoid duplicate requests for nearly identical sizes (allow 2-pt tolerance)
        if abs(size.width - lastRequestedSize.width) < 2 && abs(size.height - lastRequestedSize.height) < 2 {
            return
        }
        lastRequestedSize = size
        imageLoader.loadImage(from: photo.asset, targetSize: size)
    }
}

// MARK: - Optimized Image Loader with Better Caching
class OptimizedImageLoader: ObservableObject {
    private static let sharedCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200 // Increased for better performance
        cache.totalCostLimit = 150 * 1024 * 1024 // 150MB
        return cache
    }()
    
    private static let imageManager: PHCachingImageManager = {
        let manager = PHCachingImageManager()
        manager.allowsCachingHighQualityImages = true
        return manager
    }()
    
    @Published var image: UIImage?
    private var requestID: PHImageRequestID?
    private var currentAssetID: String?
    private var cacheObserver: NSObjectProtocol?
    private var loadingTask: Task<Void, Never>?
    
    init() {
        // Listen for cache clear notifications
        cacheObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ClearOldImageCache"),
            object: nil,
            queue: .main
        ) { notification in
            if let keepIds = notification.userInfo?["keepIds"] as? Set<String> {
                Self.clearCacheSelectively(keepIds: keepIds)
            }
        }
    }
    
    deinit {
        cancelLoading()
        if let observer = cacheObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func loadImage(from asset: PHAsset, targetSize: CGSize) {
        let assetID = asset.localIdentifier
        
        // Skip if already loading this asset
        if currentAssetID == assetID && image != nil {
            return
        }
        
        currentAssetID = assetID
        
        // Check cache first
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        let cacheKey = NSString(string: "\(assetID)_\(Int(pixelSize.width))x\(Int(pixelSize.height))")
        
        if let cachedImage = Self.sharedCache.object(forKey: cacheKey) {
            DispatchQueue.main.async {
                self.image = cachedImage
            }
            return
        }
        
        // Cancel any existing request
        cancelLoading()
        
        // Two-step request: FAST thumbnail first, then crisp HQ.

        func request(_ delivery: PHImageRequestOptionsDeliveryMode) {
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.deliveryMode = delivery
            opts.resizeMode = delivery == .fastFormat ? .fast : .exact
            opts.isSynchronous = false
            opts.version = .current
            self.requestID = Self.imageManager.requestImage(
                for: asset,
                targetSize: pixelSize,
                contentMode: .aspectFill,
                options: opts
            ) { [weak self] image, info in
                guard let self = self, self.currentAssetID == assetID else { return }
                
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

                #if DEBUG
                let modeStr = delivery == .fastFormat ? "FAST" : delivery == .opportunistic ? "OPPORTUNISTIC" : "HQ"
                print("📥 OptimizedImageLoader asset=\(assetID.suffix(8)) mode=\(modeStr) degraded=\(isDegraded) size=\(pixelSize)")
                #endif
                
                DispatchQueue.main.async {
                    if let image = image {
                        // Always show the image, even if degraded – the HQ version will overwrite later.
                        self.image = image
                        
                        // Only cache high-quality images (non-degraded) to save memory.
                        if !isDegraded {
                            let cost = Int(image.size.width * image.size.height * 4)
                            Self.sharedCache.setObject(image, forKey: cacheKey, cost: cost)
                        }
                    }
                }
            }
        }
        // Step 1: fast thumbnail
        request(.fastFormat)
        // Step 2: high-quality replacement (after slight delay to avoid duplicate burst on slow assets)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            request(.highQualityFormat)
        }
    }
    
    func cancelLoading() {
        loadingTask?.cancel()
        if let requestID = requestID {
            Self.imageManager.cancelImageRequest(requestID)
            self.requestID = nil
        }
    }
    
    static func clearCache() {
        sharedCache.removeAllObjects()
    }
    
    static func clearCacheSelectively(keepIds: Set<String>) {
        // NSCache does not expose its keys, so we must track them ourselves or clear all and re-cache essentials.
        // For now, safest is to clear all and rely on prefetch to re-cache needed images.
        sharedCache.removeAllObjects()
    }
}

// MARK: - Card Components

/// A standardized card component with consistent styling
struct StandardCard<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let cornerRadius: CGFloat
    let content: () -> Content
    
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }
    
    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.border(for: themeManager.isDarkMode), lineWidth: 1)
            )
            .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Stat Badge Components

/// A small badge showing statistics with icon
struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Gradient Button Style

/// A button style with gradient background
struct GradientButtonStyle: ButtonStyle {
    let colors: [Color]
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    
    init(
        colors: [Color] = [.blue, .purple],
        cornerRadius: CGFloat = 16,
        horizontalPadding: CGFloat = 24,
        verticalPadding: CGFloat = 16
    ) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Loading Overlay

/// A standardized loading overlay component
struct LoadingOverlay: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.body)
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
        )
        .shadow(radius: 10)
    }
}

// MARK: - Empty State View

/// A reusable empty state view component
struct EmptyStateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        icon: String,
        title: String,
        message: String,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                
                Text(message)
                    .font(.body)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    .multilineTextAlignment(.center)
            }
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .buttonStyle(GradientButtonStyle())
            }
        }
        .padding(40)
    }
}

// MARK: - Toast Notification

/// A toast notification component for showing brief success messages
struct ToastView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: String
    @Binding var isShowing: Bool
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        if isShowing {
            VStack {
                Spacer()
                
                HStack(spacing: DeviceInfo.shared.spacing(0.6)) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.body, weight: .medium))
                    
                    Text(message)
                        .adaptiveFont(.body)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, DeviceInfo.shared.spacing(1.0))
                .padding(.vertical, DeviceInfo.shared.spacing(0.8))
                .background(
                    RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                        .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                        .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 12, x: 0, y: 4)
                )
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                    
                    // Auto-hide after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scale = 0.8
                            opacity = 0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isShowing = false
                        }
                    }
                }
                
                Spacer()
                    .frame(height: DeviceInfo.shared.spacing(6.0)) // Bottom padding from safe area
            }
            .transition(.opacity.combined(with: .scale))
        }
    }
}

/// Toast Manager for handling toast notifications
class ToastManager: ObservableObject {
    @Published var isShowingToast = false
    @Published var toastMessage = ""
    
    func showToast(message: String) {
        DispatchQueue.main.async {
            self.toastMessage = message
            self.isShowingToast = true
        }
    }
    
    func hideToast() {
        DispatchQueue.main.async {
            self.isShowingToast = false
        }
    }
} 