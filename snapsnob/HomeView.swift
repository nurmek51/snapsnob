import SwiftUI
import Photos
import FirebaseAnalytics

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
    // Start fully opaque & at full scale to avoid initial flash
    @State private var photoOpacity: Double = 1.0
    @State private var photoScale: CGFloat = 1.0
    // Idle bounce hint state
    @State private var idleOffset: CGFloat = 0
    @State private var idleBounceWorkItem: DispatchWorkItem?
    // Swipe counter for periodic cache flush
    @State private var swipeCount: Int = 0
    
    // MARK: - Enhanced Animation States for Tinder-style transitions
    @State private var backgroundCards: [Photo] = []
    @State private var swipeVelocity: CGFloat = 0
    
    // MARK: - Enhanced Action Banner States
    @State private var showActionLabel: Bool = false
    @State private var actionLabelText: String = ""
    @State private var actionLabelIcon: String = ""
    @State private var actionBannerScale: CGFloat = 0.5
    @State private var actionBannerOpacity: Double = 0
    @State private var actionBannerColor: Color = .black
    @State private var actionDirection: SwipeDirection = .right
    
    // Onboarding states
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var onboardingDidSwipeRight = false
    @State private var onboardingDidSwipeLeft = false
    @State private var onboardingDidDoubleTap = false
    
    // Add SeamlessPhotoLoader instance for optimized image loading
    @StateObject private var photoLoader = SeamlessPhotoLoader()
    
    // Heart pop-up animation for double-tap favourite
    @State private var showHeartOverlay: Bool = false
    @State private var heartOverlayScale: CGFloat = 0.8
    @State private var heartOverlayOpacity: Double = 0.0
    
    // MARK: - Undo Functionality States
    @State private var lastAction: UndoAction? = nil
    @State private var photoQueue: [Photo] = []
    @State private var processedPhotos: Set<UUID> = []
    
    // Structure to store undo action data
    private struct UndoAction {
        let photo: Photo
        let action: PhotoAction
        let timestamp: Date
    }
    
    // MARK: - Permission Tracking State
    @State private var hasShownPermissionPrompt = false
    
    // MARK: - Card Size Helper
    /// Slightly larger than the default adaptive size, but still clamped to the screen width so it remains responsive.
    private var cardSize: CGSize {
        // Use the adaptive base size directly for perfect consistency across devices.
        DeviceInfo.shared.cardSize()
    }
    
    // MARK: - Shadow Properties
    private var shadowRadius: CGFloat {
        15 + abs(dragOffset.width) / 50
    }
    
    private var shadowX: CGFloat {
        dragOffset.width / 50
    }
    
    private var shadowY: CGFloat {
        4 + abs(dragOffset.width) / 100
    }
    
    // MARK: - Advanced Spring Animation Configuration
    private var swipeSpringAnimation: Animation {
        .interpolatingSpring(stiffness: 300, damping: 25)
    }
    
    private var snapBackSpringAnimation: Animation {
        .interpolatingSpring(stiffness: 500, damping: 30)
    }
    
    private var cardEntranceAnimation: Animation {
        // Smoother entrance animation to prevent flashing
        .interpolatingSpring(stiffness: 350, damping: 28)
    }
    
    @State private var hasInitialized = false // Prevents double-initialization
    
    // Add state for favorite star animation
    @State private var favoriteIconScale: CGFloat = 1.0
    @State private var favoriteIconRotation: Double = 0.0
    @State private var showFavoriteAnimation = false
    
    // Add state for action buttons animation
    @State private var actionButtonsVisible: Bool = true
    
    // MARK: - Loading Animation States
    @State private var loadingAnimationPhase: Int = 0
    @State private var loadingAnimationTimer: Timer?
    
    // MARK: - Card Corner Radius (iPad only)
    private var cardCornerRadius: CGFloat {
        DeviceInfo.shared.isIPad ? 40 : 24
    }
    
    // Add this new computed property for the stories row
    @ViewBuilder
    private var storiesRow: some View {
        if photoManager.isLoading || photoManager.photoSeries.isEmpty {
            // Placeholder: show 3 gray circles as loading state, sized for device
            let circleSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 95 : 75
            HStack(spacing: DeviceInfo.shared.screenSize.gridSpacing) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: circleSize, height: circleSize)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .redacted(reason: .placeholder)
                }
            }
        } else {
            HStack(spacing: DeviceInfo.shared.screenSize.gridSpacing) {
                ForEach(Array(photoManager.photoSeries.enumerated()), id: \.offset) { _, series in
                    VStack(spacing: DeviceInfo.shared.spacing(0.3)) {
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
            }
        }
    }
    
    var body: some View {
        Group {
            if DeviceInfo.shared.isIPad {
                // iPad: No NavigationView, show main content directly
                VStack(spacing: 0) {
                    let isAccessDenied = photoManager.authorizationStatus == .denied || photoManager.authorizationStatus == .restricted
                    if isAccessDenied {
                        photoAccessDeniedView
                    } else if photoManager.isLoading {
                        loadingView
                    } else {
                        mainContentView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background(for: themeManager.isDarkMode))
            } else {
                // iPhone: Use NavigationView
                NavigationView {
                    VStack(spacing: 0) {
                        let isAccessDenied = photoManager.authorizationStatus == .denied || photoManager.authorizationStatus == .restricted
                        if isAccessDenied {
                            photoAccessDeniedView
                        } else if photoManager.isLoading {
                            loadingView
                        } else {
                            mainContentView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background(for: themeManager.isDarkMode))
                }
                .navigationBarHidden(true)
                .navigationViewStyle(.stack)
            }
        }
        // All the rest of your view modifiers (onAppear, onReceive, etc.) remain outside the Group
        .onAppear {
            print("📱 HomeView appeared")
            if !photoManager.isLoading && !hasInitialized && (!photoManager.nonSeriesPhotos.isEmpty || !photoManager.photoSeries.isEmpty || !photoManager.trashedPhotos.isEmpty) {
                hasInitialized = true
                loadInitialPhotos()
                scheduleIdleBounce()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PhotoRestoredFromTrash"))) { notification in
            if let photoId = notification.userInfo?["photoId"] as? UUID {
                handlePhotoRestoredFromTrash(photoId: photoId)
            }
        }
        .onChange(of: photoManager.isLoading) { _, isLoading in
            if !isLoading && !hasInitialized && (!photoManager.nonSeriesPhotos.isEmpty || !photoManager.photoSeries.isEmpty || !photoManager.trashedPhotos.isEmpty) {
                hasInitialized = true
                loadInitialPhotos()
                scheduleIdleBounce()
            }
        }
        .onChange(of: photoManager.nonSeriesPhotos) { _, newPhotos in
            if !photoManager.isLoading && !hasInitialized && (!newPhotos.isEmpty || !photoManager.photoSeries.isEmpty || !photoManager.trashedPhotos.isEmpty) {
                hasInitialized = true
                loadInitialPhotos()
                scheduleIdleBounce()
            }
            guard !isProcessingAction && !isTransitioning else { return }
            guard let current = currentPhoto else {
                rebuildPhotoQueue()
                if let first = photoQueue.first {
                    currentPhoto = first
                    photoManager.prefetchThumbnails(for: [first], targetSize: cardSize)
                    preloadNextPhotos()
                }
                scheduleIdleBounce()
                return
            }
            let stillValid = photoManager.nonSeriesPhotos.contains { $0.id == current.id }
            guard !stillValid else { return }
            if photoManager.nonSeriesPhotos.isEmpty {
                currentPhoto = nil
                nextPhoto = nil
                photoQueue = []
            } else {
                rebuildPhotoQueue()
                if let first = photoQueue.first {
                    currentPhoto = first
                    photoManager.prefetchThumbnails(for: [first], targetSize: cardSize)
                    preloadNextPhotos()
                }
            }
            scheduleIdleBounce()
        }
        // Remove .onChange blocks for photoManager.photoSeries and photoManager.trashedPhotos
        .sheet(isPresented: $showingTrash) {
            TrashView(photoManager: photoManager)
        }
        .fullScreenCover(isPresented: $showingAIAnalysis) {
            AIAnalysisView {
                showingAIAnalysis = false
            }
            .environmentObject(photoManager)
            .environmentObject(aiAnalysisManager)
        }
        // Onboarding overlay
        .overlay {
            HomeViewOnboarding(
                didSwipeRight: $onboardingDidSwipeRight,
                didSwipeLeft: $onboardingDidSwipeLeft,
                didDoubleTap: $onboardingDidDoubleTap
            )
            .environmentObject(themeManager)
            .zIndex(100) // Ensure it's above photo cards
        }
        // Undo button overlay
        // (global banner overlay removed – banner now lives on the card)
    }
    
    // MARK: - View Components
    
    // Add a computed property for adaptive story circle top padding
    private var storyCircleTopPadding: CGFloat {
        // Match the circleSize in StoryCircle
        let circleSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 95 : 75
        // Add border width and shadow (max 8pt on iPad, 6pt on iPhone)
        let borderAndShadow: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 8 : 6
        // Add a little extra for safety
        return (circleSize / 2) + borderAndShadow + DeviceInfo.shared.spacing(0.5)
    }
    
    @ViewBuilder
    private var photoAccessDeniedView: some View {
        VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 30 : 20) {
            // Icon with app's theme colors
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 60))
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
            
            VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8) {
                Text("photo.accessDenied".localized)
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .largeTitle : .title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                
                Text("photo.accessRequiredMessage".localized)
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .body)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 40 : 20)
            }
            
            // Styled button matching app design
            Button(action: {
                print("🔧 Opening settings for photo access")
                hasShownPermissionPrompt = true
                UserDefaults.standard.set(true, forKey: "hasShownPermissionPrompt")
                
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8) {
                    Image(systemName: "gear")
                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 16, weight: .semibold))
                    Text("action.openSettings".localized)
                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 32 : 24)
                .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12)
                .background(
                    Capsule()
                        .fill(AppColors.accent(for: themeManager.isDarkMode))
                        .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(hasShownPermissionPrompt ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: hasShownPermissionPrompt)
        }
        .padding(UIDevice.current.userInterfaceIdiom == .pad ? 40 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .constrainedToDevice(usePadding: false)
        .onAppear {
            // Load permission prompt state
            hasShownPermissionPrompt = UserDefaults.standard.bool(forKey: "hasShownPermissionPrompt")
            print("📱 Permission denied view appeared. Has shown prompt: \(hasShownPermissionPrompt)")
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: DeviceInfo.shared.spacing(2.0)) {
            // App icon/logo placeholder
            Image(systemName: "photo.stack")
                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 60, weight: .light))
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                .opacity(0.8)
            
            // Loading title
            Text("photo.loading".localized)
                .adaptiveFont(.title)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                .multilineTextAlignment(.center)
            
            // Progress section
            VStack(spacing: DeviceInfo.shared.spacing(1.0)) {
                // Progress bar
                ProgressView(value: Double(photoManager.processedPhotosCount), total: Double(max(photoManager.allPhotos.count, 1)))
                    .progressViewStyle(LinearProgressViewStyle(tint: AppColors.accent(for: themeManager.isDarkMode)))
                    .frame(height: DeviceInfo.shared.spacing(0.4))
                    .scaleEffect(x: 1.0, y: UIDevice.current.userInterfaceIdiom == .pad ? 1.5 : 1.2, anchor: .center)
                
                // Progress text
                HStack {
                    Text("home.photosProcessed".localized(with: photoManager.processedPhotosCount, photoManager.allPhotos.count))
                        .adaptiveFont(.caption)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    
                    Spacer()
                    
                    // Percentage
                    Text("\(Int((Double(photoManager.processedPhotosCount) / Double(max(photoManager.allPhotos.count, 1))) * 100))%")
                        .adaptiveFont(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                }
                .padding(.horizontal, DeviceInfo.shared.spacing(0.5))
            }
            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 400 : 280)
            .padding(.horizontal, DeviceInfo.shared.spacing(1.0))
            
            // Loading animation dots
            HStack(spacing: DeviceInfo.shared.spacing(0.3)) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppColors.accent(for: themeManager.isDarkMode))
                        .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8, height: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8)
                        .scaleEffect(loadingDotScale(for: index))
                        .opacity(loadingDotOpacity(for: index))
                        .animation(
                            .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                            value: loadingAnimationPhase
                        )
                }
            }
            .padding(.top, DeviceInfo.shared.spacing(1.0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background(for: themeManager.isDarkMode))
        .onAppear {
            print("📱 HomeView loading photos...")
            startLoadingAnimation()
        }
        .onDisappear {
            stopLoadingAnimation()
        }
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header is pinned at the top
            headerSection
                // Use reliable safe area helper for consistent positioning across all devices
                .safeAreaHeader()
                .background(AppColors.background(for: themeManager.isDarkMode))
                .zIndex(10)
            
            // Photo cards section with fixed minimum height to prevent header collapse
            photoCardSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 4) // minimal gap after header
        }
        // Bottom padding scaled per device to ensure card clears the tab bar
        .padding(.bottom, DeviceInfo.shared.screenSize.bottomSectionPadding)
        .constrainedToDevice(usePadding: false)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        // --- Refactored for pixel-perfect, adaptive, and symmetric layout ---
        VStack(alignment: .leading, spacing: 0) {
            // Title with consistent top padding from status bar
            Text(Constants.Strings.photoSeries)
                .adaptiveFont(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                .adaptivePadding(1.0)
                .verticalSectionSpacing(0.5) // Consistent gap below title

            // Story row: avatar, timestamp, progress bar, trash icon
            HStack(alignment: .center, spacing: DeviceInfo.shared.screenSize.horizontalPadding) {
                // Stories conveyor (avatar row)
                ScrollView(.horizontal, showsIndicators: false) {
                    storiesRow
                        .padding(.leading, DeviceInfo.shared.screenSize.horizontalPadding)
                        .padding(.vertical, DeviceInfo.shared.spacing(0.2))
                }
                // Trash icon and label, vertically centered with story row
                VStack(spacing: DeviceInfo.shared.spacing(0.3)) {
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
                    Text(Constants.Strings.trash)
                        .adaptiveFont(.caption)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        .lineLimit(1)
                        .frame(width: DeviceInfo.shared.screenSize.horizontalPadding * 3.5)
                }
                .padding(.trailing, DeviceInfo.shared.screenSize.horizontalPadding)
            }
            .verticalSectionSpacing(0.5) // Consistent gap below story row

            // Progress Counter (processed / total) with progress bar
            let processed = photoManager.processedPhotosCount
            let total = photoManager.allPhotos.count
            VStack(spacing: DeviceInfo.shared.spacing(0.2)) {
                HStack {
                    Text("home.photosProcessed".localized(with: processed, total))
                        .adaptiveFont(.caption)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    Spacer()
                }
                ProgressView(value: Double(processed), total: Double(max(total, 1)))
                    .accentColor(AppColors.accent(for: themeManager.isDarkMode))
                    .frame(height: DeviceInfo.shared.spacing(0.4))
            }
            .adaptivePadding(1.0)
            .verticalSectionSpacing(0.2)
        }
        // Ensure the header has equal left/right padding and background
        .background(AppColors.background(for: themeManager.isDarkMode))
        // Add bottom padding to separate from cards
        .padding(.bottom, DeviceInfo.shared.spacing(0.5))
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
                        Text(Constants.Strings.noSinglePhotos)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))

                        Text(Constants.Strings.allPhotosInSeries)
                            .font(.body)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("common.noMorePhotos".localized)
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
                // Background cards for depth effect (Tinder-style)
                backgroundCardsView
                
                // Main card
                mainCardView(photo: photo)
            }
            // Apply the fixed card size so the card does not dynamically resize
            .frame(width: cardSize.width, height: cardSize.height)
            // Feedback overlays
            .overlay(heartOverlay)
            // Enhanced Action Banner
            .overlay(alignment: .top) { actionBannerView }
        }
    }
    
    @ViewBuilder
    private var backgroundCardsView: some View {
        ForEach(backgroundCards.prefix(1), id: \.id) { bgPhoto in
            if let index = backgroundCards.firstIndex(where: { $0.id == bgPhoto.id }) {
                photoCardBackground(photo: bgPhoto, index: index)
            }
        }
    }
    
    @ViewBuilder
    private func mainCardView(photo: Photo) -> some View {
        ZStack {
            // Gradient backdrop
            gradientBackdrop
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            // Card with shadow
            cardWithShadow
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            // Photo
            SeamlessPhotoView(photo: photo, targetSize: cardSize)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                .transition(.opacity.combined(with: .scale))
            
            // Swipe indicators
            swipeIndicatorOverlay
            
            // Action buttons
            actionButtonsOverlay
        }
        .rotationEffect(.degrees(dragRotation))
        .offset(x: dragOffset.width + idleOffset, y: dragOffset.height)
        .scaleEffect(photoScale)
        .opacity(photoOpacity)
        .gesture(swipeGesture)
        .highPriorityGesture(doubleTapGesture)
        .onTapGesture { if !isProcessingAction { handleTap(photo: photo) } }
    }
    
    @ViewBuilder
    private var gradientBackdrop: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.black.opacity(0.4)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .scaleEffect(max(0.95 - abs(dragOffset.width) / 1000, 0.9))
    }
    
    @ViewBuilder
    private var cardWithShadow: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius)
            .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
            .shadow(
                color: AppColors.shadow(for: themeManager.isDarkMode).opacity(0.3),
                radius: shadowRadius,
                x: shadowX,
                y: shadowY
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .stroke(AppColors.border(for: themeManager.isDarkMode), lineWidth: 2)
            )
    }
    
    @ViewBuilder
    private var swipeIndicatorOverlay: some View {
        Group {
            if dragOffset.width < -50 {
                // Trash indicator
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                            .opacity(trashIndicatorOpacity)
                            .scaleEffect(trashIndicatorScale)
                        Spacer()
                    }
                    .padding(.trailing, 30)
                    .padding(.top, 30)
                }
            } else if dragOffset.width > 50 {
                // Keep indicator
                HStack {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                            .opacity(keepIndicatorOpacity)
                            .scaleEffect(keepIndicatorScale)
                        Spacer()
                    }
                    .padding(.leading, 30)
                    .padding(.top, 30)
                    Spacer()
                }
            }
        }
    }
    
    // Computed properties for indicator animations
    private var trashIndicatorOpacity: Double {
        Double(min(abs(dragOffset.width) / 150.0, 1.0))
    }
    
    private var trashIndicatorScale: CGFloat {
        CGFloat(min(abs(dragOffset.width) / 150.0, 1.2))
    }
    
    private var keepIndicatorOpacity: Double {
        Double(min(dragOffset.width / 150.0, 1.0))
    }
    
    private var keepIndicatorScale: CGFloat {
        CGFloat(min(dragOffset.width / 150.0, 1.2))
    }
    
    @ViewBuilder
    private var actionButtonsOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: DeviceInfo.shared.screenSize.horizontalPadding * 1.5) {
                // Trash button
                trashButton
                
                // Favorite button
                favoriteButton
                
                // Keep button
                keepButton
            }
            .padding(.bottom, DeviceInfo.shared.screenSize.horizontalPadding * 2)
            .scaleEffect(actionButtonsVisible ? 1.0 : 0.85)
            .opacity(actionButtonsVisible ? 1.0 : 0.0)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: actionButtonsVisible)
        }
    }
    
    private var trashButton: some View {
        Button(action: { handleAction(.trash) }) {
            Image(systemName: "xmark")
                .adaptiveFont(.title)
                .fontWeight(.semibold)
        }
        .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
        .disabled(isProcessingAction)
        .scaleEffect(dragOffset.width < -50 ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragOffset.width)
    }
    
    @ViewBuilder
    private var favoriteButton: some View {
        let latestPhoto = currentPhoto.flatMap { cp in photoManager.displayPhotos.first(where: { $0.asset.localIdentifier == cp.asset.localIdentifier }) } ?? currentPhoto
        Button(action: { toggleFavoriteHome() }) {
            Image(systemName: (latestPhoto?.isFavorite ?? false) ? "heart.fill" : "heart")
                .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title, weight: .semibold))
                .foregroundColor((latestPhoto?.isFavorite ?? false) ? .red : AppColors.primaryText(for: themeManager.isDarkMode))
                .scaleEffect(favoriteIconScale)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: favoriteIconScale)
        }
        .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
        .disabled(isProcessingAction)
    }
    
    private var keepButton: some View {
        Button(action: { handleAction(.keep) }) {
            Image(systemName: "checkmark")
                .adaptiveFont(.title)
                .fontWeight(.semibold)
        }
        .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
        .disabled(isProcessingAction)
        .scaleEffect(dragOffset.width > 50 ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragOffset.width)
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isProcessingAction {
                    // Cancel any pending idle bounce while user is interacting
                    idleBounceWorkItem?.cancel()
                    
                    // Direct updates for smooth dragging
                    dragOffset = value.translation
                    // More responsive rotation with velocity consideration
                    let velocity = value.velocity.width
                    dragRotation = Double(value.translation.width / 20) + Double(velocity / 500)
                    dragRotation = max(-45, min(45, dragRotation)) // Clamp rotation
                    
                    // Track velocity for physics-based animations
                    swipeVelocity = value.velocity.width
                }
            }
            .onEnded { value in
                if !isProcessingAction {
                    handleDragEnd(value: value)
                }
            }
    }
    
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                // Trigger onboarding if in double tap step
                if onboardingManager.currentStep == .doubleTap {
                    onboardingDidDoubleTap = true
                }
                animateHeartPop()
                toggleFavoriteHome()
            }
    }
    
    @ViewBuilder
    private var heartOverlay: some View {
        Group {
            if showHeartOverlay {
                Image(systemName: "heart.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 100))
                    .scaleEffect(heartOverlayScale)
                    .opacity(heartOverlayOpacity)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: heartOverlayScale)
                    .animation(.easeOut(duration: 0.4), value: heartOverlayOpacity)
                    .onAppear {
                        // Animate heart pop with spring physics
                        heartOverlayScale = 1.5
                        heartOverlayOpacity = 0.8
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            heartOverlayOpacity = 0.0
                        }
                        
                        // Remove after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            showHeartOverlay = false
                            heartOverlayScale = 0.8
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private var actionBannerView: some View {
        if showActionLabel {
            // Main banner with undo functionality
            Button(action: {
                // Only allow undo if there's a recent action
                if lastAction != nil {
                    performUndo()
                }
            }) {
                HStack(spacing: DeviceInfo.shared.spacing(1.2)) {
                    // Action icon
                    Image(systemName: actionLabelIcon)
                        .font(.system(size: DeviceInfo.shared.spacing(2.0), weight: .bold))
                        .foregroundColor(actionBannerTextColor)
                        .scaleEffect(1.1)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    
                    // Action text
                    Text(actionLabelText)
                        .font(.system(size: DeviceInfo.shared.spacing(1.6), weight: .heavy, design: .rounded))
                        .foregroundColor(actionBannerTextColor)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    
                    // Undo icon (only show if there's an action to undo)
                    if lastAction != nil {
                        Image(systemName: "arrow.uturn.left")
                            .font(.system(size: DeviceInfo.shared.spacing(1.8), weight: .bold))
                            .foregroundColor(actionBannerTextColor)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    }
                }
                .padding(.horizontal, DeviceInfo.shared.spacing(3.5))
                .padding(.vertical, DeviceInfo.shared.spacing(1.8))
                .background(
                    Group {
                        if actionLabelText == "Undo" {
                            Capsule().fill(Color.black)
                        } else {
                            LinearGradient(
                                colors: [
                                    actionBannerColor,
                                    actionBannerColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                )
                .clipShape(Capsule())
                .overlay(
                    // Subtle border without complex gradients
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: actionBannerColor.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
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
    
    // MARK: - Background Card View
    @ViewBuilder
    private func photoCardBackground(photo: Photo, index: Int) -> some View {
        let scale = 1.0 // Match main card size exactly for seamless transition
        // Remove yOffset to prevent position mismatch during transition
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                .shadow(color: AppColors.shadow(for: themeManager.isDarkMode).opacity(0.05), 
                        radius: 2, x: 0, y: 1)
            SeamlessPhotoView(photo: photo, targetSize: cardSize)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .scaleEffect(scale)
        // Position background card exactly behind main card to prevent visual jump
        .zIndex(-1)
    }
    
    // MARK: - Photo Loading Logic (Optimized for Zero-Lag Swipes)
    
    private func loadInitialPhotos() {
        guard !photoManager.nonSeriesPhotos.isEmpty else {
            currentPhoto = nil
            nextPhoto = nil
            return
        }

        // Build photo queue excluding favorites and already processed
        rebuildPhotoQueue()
        // Ensure background cards are up-to-date before display
        updateBackgroundCards()
        
        // Load first two photos
        if let first = photoQueue.first {
            currentPhoto = first
            photoManager.prefetchThumbnails(for: [first], targetSize: cardSize)
            
            // Smooth entrance without any scale animation to prevent flashing
            photoOpacity = 1.0 // Start fully opaque  
            photoScale = 1.0 // Start at full size immediately
            // No animation - instant appearance for smooth transitions
        }
        
        // Preload next photos for background cards and smooth transitions
        preloadNextPhotos()
    }
    
    private func rebuildPhotoQueue() {
        // Get all non-series, non-favorite photos that haven't been processed
        let availablePhotos = photoManager.nonSeriesPhotos.filter { photo in
            !photo.isFavorite && !processedPhotos.contains(photo.id)
        }
        // Shuffle for random order
        photoQueue = availablePhotos.shuffled()
        // Refresh background deck based on the new queue
        updateBackgroundCards()
    }
    
    /// Updates the `backgroundCards` array with a subtle scale animation only when the underlying data changes.
    private func updateBackgroundCards() {
        let desired = photoQueue.count > 1 ? Array(photoQueue.prefix(2).dropFirst()) : []

        // Skip if nothing changed to avoid needless animations
        if desired.map(\.id) != backgroundCards.map(\.id) {
            withAnimation(AppAnimations.backgroundCardScale) {
                backgroundCards = desired
            }
        }
    }
    
    private func preloadNextPhotos() {
        // Preload next 3 photos for instant transitions
        let photosToPreload = Array(photoQueue.prefix(4).dropFirst())
        guard !photosToPreload.isEmpty else { return }
        
        // Use the new SeamlessPhotoLoader for better preloading
        photoLoader.preloadPhotos(photosToPreload, targetSize: self.cardSize)
        
        // Also keep the original prefetch for compatibility
        DispatchQueue.global(qos: .userInitiated).async {
            self.photoManager.prefetchThumbnails(for: photosToPreload, targetSize: self.cardSize)
        }
    }
    
    private func advanceToNextPhoto() {
        guard !isTransitioning else { return }
        isTransitioning = true

        // 1️⃣ Fade out the current card (cross-fade & slight scale)
        withAnimation(AppAnimations.cardTransition) {
            photoOpacity = 0
            photoScale = 0.95
            actionButtonsVisible = false // Hide buttons with outgoing card
        }

        // 2️⃣ After the fade-out completes, swap the data & prepare next card
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Remove the processed photo
            if let current = currentPhoto {
                processedPhotos.insert(current.id)
                photoQueue.removeAll { $0.id == current.id }
            }

            // Determine the next photo
            if let next = photoQueue.first {
                currentPhoto = next
            } else {
                // Rebuild queue if empty
                rebuildPhotoQueue()
                currentPhoto = photoQueue.first
            }

            // Sync background deck
            updateBackgroundCards()
            preloadNextPhotos()

            // Memory housekeeping
            swipeCount += 1
            if swipeCount % 10 == 0 { cleanupMemory() }

            // 3️⃣ Instantly show the new card, no animation or bounce
            photoOpacity = 1.0
            photoScale = 1.0
            actionButtonsVisible = false // Start hidden
            // Animate buttons in after a short delay for polish
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    actionButtonsVisible = true
                }
            }

            // Finish transition & re-enable interactions
            scheduleIdleBounce()
            isTransitioning = false
        }
    }
    
    private func cleanupMemory() {
        // Clear old processed photos if too many
        if processedPhotos.count > 100 {
            processedPhotos.removeAll()
        }
        
        // Clear SeamlessPhotoLoader cache for better memory management
        photoLoader.clearCache()
        
        // Selective cache clearing
        DispatchQueue.global(qos: .utility).async {
            self.photoManager.clearOldCaches()
        }
    }

    // MARK: - User Interactions
    
    enum PhotoAction {
        case trash, favorite, keep
    }
    
    private func handleAction(_ action: PhotoAction) {
        guard let photo = currentPhoto, !isProcessingAction else { return }
        
        // 🔊 Feedback
        SoundManager.playClick()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // Cancel any pending idle hint
        idleBounceWorkItem?.cancel()
        isProcessingAction = true
        
        // Store action for undo functionality
        lastAction = UndoAction(photo: photo, action: action, timestamp: Date())
        
        // Always show 'Undo' as the banner text
        showActionBanner(text: "Undo", icon: action == .trash ? "trash" : action == .favorite ? "heart.fill" : "checkmark", direction: action == .trash ? .left : action == .favorite ? .down : .right)
        
        switch action {
        case .trash:
            photoManager.moveToTrash(photo)
            animateActionAndAdvance(direction: .left)
        case .favorite:
            photoManager.setFavorite(photo, isFavorite: !photo.isFavorite)
            photoManager.markReviewed(photo)
            // Update currentPhoto, photoQueue, and backgroundCards with the latest Photo
            if let updated = photoManager.displayPhotos.first(where: { $0.asset.localIdentifier == photo.asset.localIdentifier }) {
                currentPhoto = updated
                photoQueue = photoQueue.map { $0.asset.localIdentifier == updated.asset.localIdentifier ? updated : $0 }
                backgroundCards = backgroundCards.map { $0.asset.localIdentifier == updated.asset.localIdentifier ? updated : $0 }
                // Keep background deck in sync & animated
                updateBackgroundCards()
            }
            animateActionAndAdvance(direction: .down)
        case .keep:
            photoManager.markReviewed(photo)
            animateActionAndAdvance(direction: .right)
        }
        
        // Log action for debugging
        print("🔄 Action stored for undo: \(action), Photo: \(photo.asset.localIdentifier)")
    }
    
    // MARK: - Undo Functionality
    
    private func performUndo() {
        guard let undoAction = lastAction else {
            print("⚠️ No action to undo")
            return
        }
        print("🔄 Performing undo for action: \(undoAction.action)")
        // Reverse the action
        switch undoAction.action {
        case .trash:
            photoManager.restoreFromTrash(undoAction.photo)
        case .favorite:
            photoManager.setFavorite(undoAction.photo, isFavorite: false)
            photoManager.unmarkReviewed(undoAction.photo)
        case .keep:
            photoManager.unmarkReviewed(undoAction.photo)
        }
        // Insert photo back at the beginning of queue
        photoQueue.insert(undoAction.photo, at: 0)
        processedPhotos.remove(undoAction.photo.id)
        // Swap current photo with undone photo
        currentPhoto = undoAction.photo
        // Animated background deck refresh
        updateBackgroundCards()
        // Clear the last action
        lastAction = nil
        // Provide feedback
        SoundManager.playClick()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Smooth entrance without any scale animation to prevent flashing
        photoOpacity = 1.0 // Start fully opaque
        photoScale = 1.0 // Start at full size immediately
        // No animation - instant appearance for smooth transitions
        // Always show 'Undo' as the banner text
        showActionBanner(text: "Undo", icon: "arrow.uturn.left", direction: .right)
        print("✅ Undo completed successfully")
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
        
        // Clean exit animation with extended timing for undo functionality
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showActionLabel = false
                actionBannerOpacity = 0
                actionBannerScale = 0.8
                // Clear the last action when banner disappears
                lastAction = nil
            }
        }
    }
    
    // MARK: - Banner Color Helper
    private func getBannerColor(for text: String) -> Color {
        // Use a consistent accent color for the banner background
        return AppColors.accent(for: themeManager.isDarkMode)
    }

    // MARK: - Banner Text Color Helper
    private var actionBannerTextColor: Color {
        // For Undo, always white; otherwise, theme-based
        actionLabelText == "Undo" ? .white : (themeManager.isDarkMode ? .black : .white)
    }
    
    private func handleTap(photo: Photo) {
        withAnimation(AppAnimations.modal) {
            fullScreenPhotoManager.selectedPhoto = photo
        }
    }
    
    private func handleDragEnd(value: DragGesture.Value) {
        let horizontalThreshold: CGFloat = 100
        let velocityThreshold: CGFloat = 500
        let translation = value.translation
        let velocity = value.velocity
        
        // Check if swipe passes threshold (position or velocity)
        if abs(translation.width) > horizontalThreshold || abs(velocity.width) > velocityThreshold {
            // Determine direction
            if translation.width < 0 || velocity.width < -velocityThreshold {
                // Trigger onboarding if in left swipe step
                if onboardingManager.currentStep == .leftSwipe {
                    onboardingDidSwipeLeft = true
                }
                handleAction(.trash)
            } else {
                // Trigger onboarding if in right swipe step
                if onboardingManager.currentStep == .rightSwipe {
                    onboardingDidSwipeRight = true
                }
                handleAction(.keep)
            }
        } else {
            // Snap back with spring physics
            withAnimation(snapBackSpringAnimation) {
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
        
        // Calculate throw distance based on velocity
        let throwMultiplier = max(1.0, abs(swipeVelocity) / 500)
        let baseDistance = UIScreen.main.bounds.width * 1.5
        
        switch direction {
        case .left:
            targetOffset = CGSize(width: -baseDistance * throwMultiplier, height: 50)
            targetRotation = -30
        case .right:
            targetOffset = CGSize(width: baseDistance * throwMultiplier, height: 50)
            targetRotation = 30
        case .down:
            targetOffset = CGSize(width: 0, height: UIScreen.main.bounds.height)
            targetRotation = 0
        }
        
        // Use physics-based spring animation
        withAnimation(swipeSpringAnimation) {
            dragOffset = targetOffset
            dragRotation = targetRotation
            photoOpacity = 0
            photoScale = 0.8
        }
        
        // Advance to next photo with precisely timed delay to prevent flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Reset all states
            self.dragOffset = .zero
            self.dragRotation = 0
            self.swipeVelocity = 0
            self.isProcessingAction = false
            
            // Advance to next
            self.advanceToNextPhoto()
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

    // Add the toggleFavoriteHome function
    private func toggleFavoriteHome() {
        guard let photo = currentPhoto else { return }
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        // Play sound feedback
        SoundManager.playClick()
        // Start animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            favoriteIconScale = 1.3
        }
        // Toggle favorite state in PhotoManager
        photoManager.setFavorite(photo, isFavorite: !photo.isFavorite)
        // --- Removed manual update of currentPhoto, photoQueue, and backgroundCards ---
        // Reset scale after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                favoriteIconScale = 1.0
            }
        }
        print((photo.isFavorite ? "⭐ Added to favorites" : "💔 Removed from favorites"))
    }
    
    // Handle photo restored from trash - bring it to the top of the feed
    private func handlePhotoRestoredFromTrash(photoId: UUID) {
        print("🔄 Handling photo restored from trash: \(photoId)")
        
        // Find the restored photo in the available photos
        if let restoredPhoto = photoManager.nonSeriesPhotos.first(where: { $0.id == photoId }) {
            // Remove it from processed photos set if it exists
            processedPhotos.remove(restoredPhoto.id)
            
            // Add it to the top of the photo queue
            photoQueue.removeAll { $0.id == restoredPhoto.id } // Remove duplicates
            photoQueue.insert(restoredPhoto, at: 0)
            
            // Make it the current photo so it appears immediately
            currentPhoto = restoredPhoto
            
            // Animated background deck refresh
            updateBackgroundCards()
            
            // Prefetch thumbnail for immediate display
            photoManager.prefetchThumbnails(for: [restoredPhoto], targetSize: cardSize)
            
            // Smooth entrance without any scale animation to prevent flashing
            photoOpacity = 1.0 // Start fully opaque
            photoScale = 1.0 // Start at full size immediately
            // No animation - instant appearance for smooth transitions
            
            // Provide feedback
            SoundManager.playClick()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            // Show confirmation banner
            showActionBanner(text: "Undo", icon: "arrow.clockwise", direction: .right)
            
            // Schedule idle bounce
            scheduleIdleBounce()
            
            print("✅ Photo restored to top of feed successfully")
        } else {
            print("⚠️ Could not find restored photo in available feed")
        }
    }

    private func handleSwipe(photoID: String) {
        print("[Analytics] photo_swiped event sent for photoID: \(photoID)")
        Analytics.logEvent("photo_swiped", parameters: [
            "timestamp": Date().timeIntervalSince1970,
            "photo_id": photoID
        ])
    }

    // MARK: - Loading Animation Helpers
    
    private func startLoadingAnimation() {
        loadingAnimationTimer?.invalidate()
        loadingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                loadingAnimationPhase += 1
            }
        }
    }
    
    private func stopLoadingAnimation() {
        loadingAnimationTimer?.invalidate()
        loadingAnimationTimer = nil
    }
    
    private func loadingDotScale(for index: Int) -> CGFloat {
        let phase = loadingAnimationPhase % 3
        return phase == index ? 1.3 : 0.8
    }
    
    private func loadingDotOpacity(for index: Int) -> Double {
        let phase = loadingAnimationPhase % 3
        return phase == index ? 1.0 : 0.4
    }
    
    // MARK: - Supporting Types

    enum SwipeDirection {
        case left, right, down
    }

    // Components have been moved to CommonUIComponents.swift

    // Remove or comment out the #Preview macro to fix circular reference error
    // #Preview {
    //     HomeView()
    // }
}
