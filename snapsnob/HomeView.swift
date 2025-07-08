import SwiftUI
import Photos

// MARK: - Home View
/// The main feed view showing single photos and story series
struct HomeView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var aiAnalysisManager: AIAnalysisManager
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAIAnalysis = false
    @State private var showingTrash = false
    @State private var trashIconScale: CGFloat = 1.0
    @State private var trashIconRotation: Double = 0
    
    // New optimized photo feed state
    @State private var currentPhoto: Photo?
    @State private var nextPhoto: Photo?
    @State private var isTransitioning = false
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0
    @State private var isProcessingAction = false
    
    // Animation states
    @State private var photoOpacity: Double = 0
    @State private var photoScale: CGFloat = 0.8
    // Idle bounce hint state
    @State private var idleOffset: CGFloat = 0
    @State private var idleBounceWorkItem: DispatchWorkItem?
    // Swipe counter for periodic cache flush
    @State private var swipeCount: Int = 0
    
    // MARK: - Enhanced Action Banner States
    @State private var showActionLabel: Bool = false
    @State private var actionLabelText: String = ""
    @State private var actionLabelIcon: String = ""
    @State private var actionBannerScale: CGFloat = 0.5
    @State private var actionBannerOpacity: Double = 0
    @State private var actionBannerColor: Color = .black
    @State private var actionDirection: SwipeDirection = .right
    
    // Heart pop-up animation for double-tap favourite
    @State private var showHeartOverlay: Bool = false
    @State private var heartOverlayScale: CGFloat = 0.8
    @State private var heartOverlayOpacity: Double = 0.0
    
    // Safe-area top padding helper
    private var topSafePadding: CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        // Align header just below the Dynamic Island / status bar.
        return keyWindow?.safeAreaInsets.top ?? 44
    }
    
    // Header height measurement no longer needed with VStack layout
    
    // MARK: - Card Size Helper
    /// Slightly larger than the default adaptive size, but still clamped to the screen width so it remains responsive.
    private var cardSize: CGSize {
        // Use the adaptive base size directly for perfect consistency across devices.
        DeviceInfo.shared.cardSize()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Check authorization status separately for better type checking
                let isAccessDenied = photoManager.authorizationStatus == .denied || photoManager.authorizationStatus == .restricted
                
                if isAccessDenied {
                    // Photo Access Denied View
                    photoAccessDeniedView
                } else if photoManager.isLoading {
                    // Loading View
                    loadingView
                } else {
                    // Main Content (shows placeholder when feed is empty)
                    mainContentView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppColors.background(for: themeManager.isDarkMode))
        .ignoresSafeArea()
        .navigationBarHidden(true)
        // Force single-column behaviour on iPad to match the iPhone UX.
        .navigationViewStyle(.stack)
        .onAppear {
            print("📱 HomeView appeared")
            loadInitialPhotos()
        }
        .onChange(of: photoManager.nonSeriesPhotos) { _, _ in
            // Avoid triggering a second card refresh while we are already
            // handling a swipe transition. This previously caused two images
            // to load per swipe (one from advanceToNextPhoto and one here).
            guard !isProcessingAction && !isTransitioning else { return }
            // If the current photo is still part of the feed there's nothing to do – prevents double loads per swipe.
            guard let current = currentPhoto else { loadCurrentPhoto(); prefetchNextPhoto(); return }

            let stillValid = photoManager.nonSeriesPhotos.contains { $0.id == current.id }
            guard !stillValid else { return }

            // Either the current card was trashed / reviewed outside swipe pipeline or feed was programmatically reset.
            // In that case load a fresh card.
            if photoManager.nonSeriesPhotos.isEmpty {
                currentPhoto = nil
                nextPhoto = nil
            } else {
                loadCurrentPhoto()
                prefetchNextPhoto()
            }
        }
        .sheet(isPresented: $showingTrash) {
            TrashView(photoManager: photoManager)
        }
        // Overlays for full-screen photo and story presentation are now handled globally by ContentView.
        .fullScreenCover(isPresented: $showingAIAnalysis) {
            AIAnalysisView {
                showingAIAnalysis = false
            }
            .environmentObject(photoManager)
            .environmentObject(aiAnalysisManager)
        }
        // (global banner overlay removed – banner now lives on the card)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var photoAccessDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
            
            Text("Доступ к фото запрещен")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
            
            Text("Разрешите доступ к фото в настройках")
                .font(.body)
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                .multilineTextAlignment(.center)
            
            Button(action: {
                print("🔧 Opening settings for photo access")
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Открыть настройки")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Загрузка фотографий...")
                .font(.body)
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("📱 HomeView loading photos...")
        }
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header is pinned at the top
            headerSection
                // Position header just below the status bar / Dynamic Island for all devices
                .padding(.top, topSafePadding * 0.6)
                .background(AppColors.background(for: themeManager.isDarkMode))
                .zIndex(10)
            
            // Photo cards section with fixed minimum height to prevent header collapse
            photoCardSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 4) // minimal gap after header
        }
        // Bottom padding scaled per device to ensure card clears the tab bar
        .padding(.bottom, DeviceInfo.shared.screenSize.horizontalPadding * 2)
        .constrainedToDevice(usePadding: false)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("Серии фото")
                    .adaptiveFont(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                Spacer()
            }
            // Align title flush to the safe horizontal edge instead of the large adaptive padding
            .padding(.horizontal, DeviceInfo.shared.screenSize.horizontalPadding)
            // Larger vertical gap so the story circles are fully visible and not cropped
            .padding(.bottom, DeviceInfo.shared.spacing(2.0))
            
            // Stories row with a static trash icon at the trailing edge.
            HStack(alignment: .top, spacing: DeviceInfo.shared.screenSize.horizontalPadding) {
                // Horizontal stories conveyor – width automatically adjusts and stops before the trash icon.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DeviceInfo.shared.screenSize.gridSpacing) {
                        ForEach(Array(photoManager.photoSeries.enumerated()), id: \.offset) { _, series in
                            StoryCircle(
                                series: series,
                                photoManager: photoManager,
                                isViewed: series.isViewed,
                                onTap: {
                                    print("📱 Story tapped: \(series.title)")
                                    withAnimation(AppAnimations.modal) {
                                        fullScreenPhotoManager.selectedSeries = series
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DeviceInfo.shared.screenSize.horizontalPadding)
                }
                // Static trash icon area – sits on the same layer as stories conveyor, no overlapping.
                VStack(spacing: 6) {
                    Button(action: {
                        print("🗑️ Trash button pressed")
                        showingTrash = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                                .frame(width: DeviceInfo.shared.screenSize.horizontalPadding * 3.5,
                                       height: DeviceInfo.shared.screenSize.horizontalPadding * 3.5)
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.border(for: themeManager.isDarkMode), lineWidth: 2)
                                )
                            Image(systemName: "trash")
                                .adaptiveFont(.title)
                                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                .scaleEffect(trashIconScale)
                                .rotationEffect(.degrees(trashIconRotation))
                            if !photoManager.trashedPhotos.isEmpty {
                                Text("\(photoManager.trashedPhotos.count)")
                                    .adaptiveFont(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(DeviceInfo.shared.spacing(0.4))
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: DeviceInfo.shared.screenSize.horizontalPadding * 1.2,
                                            y: -DeviceInfo.shared.screenSize.horizontalPadding * 1.2)
                            }
                        }
                    }
                    Text("Корзина")
                        .adaptiveFont(.caption)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        .lineLimit(1)
                        .frame(width: DeviceInfo.shared.screenSize.horizontalPadding * 3.5)
                }
            }
            // Ensure trash icon does not touch the screen edge
            .padding(.trailing, DeviceInfo.shared.screenSize.horizontalPadding)

            // Progress Counter (processed / total)
            let processed = photoManager.processedPhotosCount
            let total = photoManager.allPhotos.count
            VStack(spacing: 4) {
                HStack {
                    Text("\(processed)/\(total) фото обработано")
                        .adaptiveFont(.caption)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    Spacer()
                }
                ProgressView(value: Double(processed), total: Double(max(total, 1)))
                    .accentColor(AppColors.accent(for: themeManager.isDarkMode))
                    .frame(height: DeviceInfo.shared.spacing(0.4))
            }
            .adaptivePadding(2.0)
            .padding(.top, DeviceInfo.shared.spacing(0.5))
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var photoCardSection: some View {
        ZStack {
            if currentPhoto == nil {
                VStack(spacing: 20) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))

                    // Show a different message when the entire feed is empty vs. when the user has simply reached the end.
                    if photoManager.nonSeriesPhotos.isEmpty {
                        Text("Нет одиночных фотографий")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))

                        Text("Все ваши фото являются частью серий")
                            .font(.body)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Больше нет фото")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 500) // Ensure minimum height to prevent header collapse
            } else {
                // Photo card with smooth loading animation
                photoCardView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var photoCardView: some View {
        if let photo = currentPhoto {
            ZStack {
                // Lightweight gradient backdrop (no blur) for depth
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.black.opacity(0.4)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                
                // Background card with border and shadow
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                    .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(AppColors.border(for: themeManager.isDarkMode), lineWidth: 2)
                    )
                
                // Photo with smooth loading
                OptimizedPhotoView(photo: photo, targetSize: cardSize)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .opacity(photoOpacity)
                    .scaleEffect(photoScale)
                
                // Action buttons overlay
                VStack {
                    Spacer()
                    HStack(spacing: DeviceInfo.shared.screenSize.horizontalPadding * 1.5) {
                        // Trash
                        Button(action: { handleAction(.trash) }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .adaptiveFont(.title)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                        .disabled(isProcessingAction)
                        
                        // Favourite
                        Button(action: { handleAction(.favorite) }) {
                            Image(systemName: photo.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(.white)
                                .adaptiveFont(.title)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                        .disabled(isProcessingAction)
                        
                        // Keep
                        Button(action: { handleAction(.keep) }) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .adaptiveFont(.title)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                        .disabled(isProcessingAction)
                    }
                    .padding(.bottom, DeviceInfo.shared.screenSize.horizontalPadding * 2)
                    .opacity(photoOpacity)
                }
            }
            .rotationEffect(.degrees(dragRotation))
            // Combine drag-driven offset with idle bounce offset so the whole card moves
            .offset(x: dragOffset.width + idleOffset, y: dragOffset.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isProcessingAction {
                            // Cancel any pending idle bounce while user is interacting
                            idleBounceWorkItem?.cancel()
                            
                            // Update position and rotation in a single state change to prevent conflicts
                            let translation = value.translation
                            dragOffset = translation
                            dragRotation = Double(translation.width / 25) // Slightly less sensitive rotation
                        }
                    }
                    .onEnded { value in
                        if !isProcessingAction {
                            handleDragEnd(value: value)
                        }
                    }
            )
            // Double-tap to favourite – high priority so it wins over single-tap
            .highPriorityGesture(
                TapGesture(count: 2)
                    .onEnded {
                        handleDoubleTap()
                    }
            )
            // Single tap opens full-screen
            .onTapGesture {
                if !isProcessingAction {
                    handleTap(photo: photo)
                }
            }
            // Apply the fixed card size so the card does not dynamically resize
            .frame(width: cardSize.width, height: cardSize.height)
            // Feedback overlays
            .overlay(
                Group {
                    if showHeartOverlay {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 100))
                            .scaleEffect(heartOverlayScale)
                            .opacity(heartOverlayOpacity)
                            .onAppear {
                                // Animate heart pop
                                withAnimation(.easeOut(duration: 0.4)) {
                                    heartOverlayScale = 1.2
                                    heartOverlayOpacity = 0.0
                                }
                                // Remove after animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    showHeartOverlay = false
                                }
                            }
                    }
                }
            )
            // Enhanced Action Banner – Simplified animations for smoother performance
            .overlay(alignment: .top) {
                if showActionLabel {
                    // Main banner with simplified styling
                    HStack(spacing: DeviceInfo.shared.spacing(1.2)) {
                        // Icon without complex rotation animations
                        Image(systemName: actionLabelIcon)
                            .font(.system(size: DeviceInfo.shared.spacing(2.0), weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(1.1)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        
                        // Text with consistent styling
                        Text(actionLabelText)
                            .font(.system(size: DeviceInfo.shared.spacing(1.6), weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    }
                    .padding(.horizontal, DeviceInfo.shared.spacing(3.5))
                    .padding(.vertical, DeviceInfo.shared.spacing(1.8))
                    .background(
                        // Simplified gradient background
                        LinearGradient(
                            colors: [
                                actionBannerColor,
                                actionBannerColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(
                        // Subtle border without complex gradients
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: actionBannerColor.opacity(0.3), radius: 6, x: 0, y: 3)
                    .scaleEffect(actionBannerScale)
                    .opacity(actionBannerOpacity)
                    .padding(.top, DeviceInfo.shared.spacing(2.5))
                    .offset(x: actionDirection == .left ? -20 : actionDirection == .right ? 20 : 0)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.6).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
        }
    }
    
    // MARK: - Photo Loading Logic (Optimized for Smooth Swipes)
    // 
    // The photo loading system uses a queue-based approach:
    // 1. currentPhoto: Currently displayed photo
    // 2. nextPhoto: Preloaded and ready for instant display
    // 
    // When user swipes:
    // - nextPhoto instantly becomes currentPhoto (no loading delay)
    // - A new nextPhoto is preloaded in background
    // 
    // This eliminates the lag between swipe animation and image appearance
    
    private func loadInitialPhotos() {
        guard !photoManager.nonSeriesPhotos.isEmpty else {
            currentPhoto = nil
            nextPhoto = nil
            return
        }

        loadCurrentPhoto()
        
        // Delay next photo prefetching slightly to prioritize current photo loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.prefetchNextPhoto()
        }
    }
    
    private func loadCurrentPhoto() {
        let available = photoManager.nonSeriesPhotos
        guard !available.isEmpty else {
            currentPhoto = nil
            return
        }

        guard let photo = available.randomElement() else {
            currentPhoto = nil
            return
        }
        print("📸 Loading random photo: \(photo.asset.localIdentifier)")
        
        // Reset animation states
        photoOpacity = 0
        photoScale = 0.8
        
        // Store previous photo ID to avoid redundant prefetching
        let previousPhotoId = currentPhoto?.id
        currentPhoto = photo
        
        // Prefetch this photo for immediate display (only if it's a new photo)
        if previousPhotoId != photo.id {
            photoManager.prefetchThumbnails(for: [photo], targetSize: cardSize)
        }
        
        // Animate in with smooth transition
        withAnimation(.easeOut(duration: 0.5)) {
            photoOpacity = 1.0
            photoScale = 1.0
        }

        // Schedule idle bounce hint after initial appear
        scheduleIdleBounce()
    }
    
    private func prefetchNextPhoto() {
        let remaining = photoManager.nonSeriesPhotos.filter { $0.id != currentPhoto?.id }
        guard let nextRandom = remaining.randomElement() else {
            nextPhoto = nil
            return
        }
        
        // Only prefetch if it's a different photo
        guard nextRandom.id != nextPhoto?.id else { return }
        
        print("📸 Prefetching next photo: \(nextRandom.asset.localIdentifier)")
        nextPhoto = nextRandom
        
        // Prefetch in background to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            photoManager.prefetchThumbnails(for: [nextRandom], targetSize: cardSize)
        }
    }
    
    private func advanceToNextPhoto() {
        guard !isTransitioning else { return }
        isTransitioning = true

        // Use preloaded next photo for instant transition
        if let next = nextPhoto {
            // Clean up cache for current photo
            if let current = currentPhoto {
                photoManager.stopPrefetchingThumbnails(for: [current], targetSize: cardSize)
            }
            
            // Important: Don't reset animation states here to prevent flash
            // Instead, update the photo directly and let SwiftUI handle the transition
            currentPhoto = next
            
            // Preload the next photo in background immediately
            prefetchNextPhoto()
            
            // Schedule idle bounce hint
            scheduleIdleBounce()
        } else {
            // Fallback: load a new photo if next wasn't available
            loadCurrentPhoto()
            prefetchNextPhoto()
        }
        
        swipeCount += 1
        if swipeCount % 12 == 0 {
            print("🧹 Clearing image caches after 12 swipes")
            photoManager.clearImageCaches()
        }
        
        isTransitioning = false
    }
    
    // MARK: - User Interactions
    
    enum PhotoAction {
        case trash, favorite, keep
    }
    
    private func handleAction(_ action: PhotoAction) {
        guard let photo = currentPhoto, !isProcessingAction else { return }
        
        // 🔊 Feedback
        SoundManager.playClick()
        
        // Cancel any pending idle hint
        idleBounceWorkItem?.cancel()
        isProcessingAction = true
        
        switch action {
        case .trash:
            showActionBanner(text: "Removed!", icon: "trash", direction: .left)
            photoManager.moveToTrash(photo)
            animateActionAndAdvance(direction: .left)
        case .favorite:
            showActionBanner(text: "Favorited!", icon: "heart.fill", direction: .down)
            photoManager.setFavorite(photo, isFavorite: !photo.isFavorite)
            photoManager.markReviewed(photo)
            animateActionAndAdvance(direction: .down)
        case .keep:
            showActionBanner(text: "Kept!", icon: "checkmark", direction: .right)
            photoManager.markReviewed(photo)
            animateActionAndAdvance(direction: .right)
        }
    }

    // MARK: - Double-tap favourite helper
    private func handleDoubleTap() {
        animateHeartPop()
        handleAction(.favorite)
    }
    
    private func animateHeartPop() {
        heartOverlayScale = 0.8
        heartOverlayOpacity = 1.0
        showHeartOverlay = true
    }

    // MARK: - Enhanced Action Banner
    private func showActionBanner(text: String, icon: String, direction: SwipeDirection = .right) {
        // Cancel any existing banner animations to prevent conflicts
        // actionBannerGlow = false // This line was removed as per the edit hint
        
        // Set content and direction
        actionLabelText = text
        actionLabelIcon = icon
        actionDirection = direction
        
        // Set color based on action type using app's theme
        actionBannerColor = getBannerColor(for: text)
        
        // Reset animation states cleanly
        actionBannerScale = 0.6
        actionBannerOpacity = 0
        
        // Single, smooth entrance animation without complex timing chains
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)) {
            showActionLabel = true
            actionBannerOpacity = 1.0
            actionBannerScale = 1.0
        }
        
        // Clean exit animation with single timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showActionLabel = false
                actionBannerOpacity = 0
                actionBannerScale = 0.8
            }
        }
    }
    
    // MARK: - Banner Color Helper
    private func getBannerColor(for text: String) -> Color {
        switch text {
        case "Removed!":
            // Use app's theme-aware colors instead of vibrant red
            return AppColors.secondaryText(for: themeManager.isDarkMode).opacity(0.8)
        case "Favorited!":
            // Use accent color instead of bright pink
            return AppColors.accent(for: themeManager.isDarkMode).opacity(0.9)
        case "Kept!":
            // Use primary text color instead of bright green
            return AppColors.primaryText(for: themeManager.isDarkMode).opacity(0.8)
        default:
            return AppColors.primaryText(for: themeManager.isDarkMode)
        }
    }
    
    private func handleTap(photo: Photo) {
        withAnimation(AppAnimations.modal) {
            fullScreenPhotoManager.selectedPhoto = photo
        }
    }
    
    private func handleDragEnd(value: DragGesture.Value) {
        let threshold: CGFloat = 80
        let translation = value.translation
        
        if translation.width < -threshold {
            handleAction(.trash)
        } else if translation.width > threshold {
            handleAction(.keep)
        } else {
            // Reset position with optimized spring animation – favourites now handled by double-tap
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                dragOffset = .zero
                dragRotation = 0
            }
            // Restart idle bounce timer after user cancels swipe
            scheduleIdleBounce()
        }
    }
    
    private func animateActionAndAdvance(direction: SwipeDirection) {
        var targetOffset: CGSize
        var targetRotation: Double = 0
        
        switch direction {
        case .left:
            targetOffset = CGSize(width: -UIScreen.main.bounds.width, height: 0)
            targetRotation = -25 // Slightly reduced rotation for smoother animation
        case .right:
            targetOffset = CGSize(width: UIScreen.main.bounds.width, height: 0)
            targetRotation = 25 // Slightly reduced rotation for smoother animation
        case .down:
            targetOffset = CGSize(width: 0, height: UIScreen.main.bounds.height)
        }
        
        // Animate card exit with optimized spring animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)) {
            dragOffset = targetOffset
            dragRotation = targetRotation
            photoOpacity = 0
        }
        
        // Advance to next photo with optimized timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Reset all gesture states cleanly
            dragOffset = .zero
            dragRotation = 0
            photoOpacity = 1.0 // Reset opacity for next card
            photoScale = 1.0   // Reset scale for next card
            isProcessingAction = false
            
            // Advance to the preloaded next photo
            advanceToNextPhoto()
        }
    }

    // MARK: - Idle Bounce Hint Logic

    /// Schedules a one-time bounce hint after 5 s of user inactivity.
    private func scheduleIdleBounce() {
        idleBounceWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            performIdleBounceHint()
        }
        idleBounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    /// Performs the subtle bounce animation to hint swipeability.
    private func performIdleBounceHint() {
        // Move slightly to the right then return.
        withAnimation(.easeInOut(duration: 0.25)) {
            idleOffset = 12
        }

        // Return to original position.
        withAnimation(.easeInOut(duration: 0.25).delay(0.25)) {
            idleOffset = 0
        }
    }

    // (global banner overlay helper removed)
}

// MARK: - Supporting Types

enum SwipeDirection {
    case left, right, down
}

// Components have been moved to CommonUIComponents.swift

#Preview {
    HomeView()
}
