import SwiftUI
import Photos
import FirebaseAnalytics
import AVKit
import AVFoundation

// MARK: - Video View
/// The main feed view showing videos with TikTok-style instant playback
struct VideoView: View {
    @EnvironmentObject var videoManager: VideoManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var videoLoader = SeamlessVideoLoader()
    
    // Current video state
    @State private var currentVideo: Video?
    @State private var nextVideo: Video?
    @State private var isTransitioning = false
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0
    @State private var isProcessingAction = false
    
    // Animation states
    @State private var videoOpacity: Double = 1.0
    @State private var videoScale: CGFloat = 1.0
    @State private var idleOffset: CGFloat = 0
    @State private var idleBounceWorkItem: DispatchWorkItem?
    @State private var swipeCount: Int = 0
    
    // Background cards for Tinder-style transitions
    @State private var backgroundCards: [Video] = []
    @State private var swipeVelocity: CGFloat = 0
    
    // Action banner states
    @State private var showActionLabel: Bool = false
    @State private var actionLabelText: String = ""
    @State private var actionLabelIcon: String = ""
    @State private var actionBannerScale: CGFloat = 0.5
    @State private var actionBannerOpacity: Double = 0
    @State private var actionBannerColor: Color = .black
    @State private var actionDirection: SwipeDirection = .right
    
    // Heart animation for double-tap favorite
    @State private var showHeartOverlay: Bool = false
    @State private var heartOverlayScale: CGFloat = 0.8
    @State private var heartOverlayOpacity: Double = 0.0
    
    // Add state for favorite star animation to match HomeView
    @State private var favoriteIconScale: CGFloat = 1.0
    
    // Trash icon animation states to match HomeView
    @State private var trashIconScale: CGFloat = 1.0
    @State private var trashIconRotation: Double = 0
    
    // Undo functionality
    @State private var lastAction: UndoAction? = nil
    @State private var videoQueue: [Video] = []
    @State private var processedVideos: Set<UUID> = []
    
    // Action buttons visibility
    @State private var actionButtonsVisible: Bool = true
    
    // Initialization state
    @State private var hasInitialized = false
    
    // Video playback state
    @State private var isCurrentVideoPlaying = true
    @State private var isCurrentVideoMuted = true
    @State private var userPausedVideo = false  // Track if user manually paused
    
    private struct UndoAction {
        let video: Video
        let action: VideoAction
        let timestamp: Date
    }
    
    // MARK: - Card Size Helper
    private var cardSize: CGSize {
        DeviceInfo.shared.cardSize()
    }
    
    // MARK: - Shadow Properties
    private var shadowRadius: CGFloat {
        15 + CGFloat(abs(dragOffset.width)) / 50.0
    }
    
    private var shadowX: CGFloat {
        CGFloat(dragOffset.width) / 50.0
    }
    
    private var shadowY: CGFloat {
        4 + CGFloat(abs(dragOffset.width)) / 100.0
    }
    
    // MARK: - Animation Configurations
    private var swipeSpringAnimation: Animation {
        .interpolatingSpring(stiffness: 300, damping: 25)
    }
    
    private var snapBackSpringAnimation: Animation {
        .interpolatingSpring(stiffness: 500, damping: 30)
    }
    
    private var cardCornerRadius: CGFloat {
        DeviceInfo.shared.isIPad ? 40 : 24
    }
    
    var body: some View {
        Group {
            if DeviceInfo.shared.isIPad {
                // iPad: No NavigationView, show main content directly
                VStack(spacing: 0) {
                    if !videoManager.hasPermission {
                        permissionView
                    } else if videoManager.isLoading {
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
                        if !videoManager.hasPermission {
                            permissionView
                        } else if videoManager.isLoading {
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
        .onAppear {
            print("📱 VideoView appeared")
            initializeVideoViewIfNeeded()
        }
        .onChange(of: videoManager.isLoading) { _, isLoading in
            print("🔄 VideoManager loading state changed: \(isLoading)")
            if !isLoading {
                initializeVideoViewIfNeeded()
            }
        }
        .onChange(of: videoManager.videos) { _, newVideos in
            print("🔄 VideoManager videos changed: \(newVideos.count) videos")
            initializeVideoViewIfNeeded()
            
            // Only rebuild queue if not processing actions and we already have a current video
            if !isProcessingAction && !isTransitioning && currentVideo != nil {
                rebuildVideoQueue()
            }
        }
    }
    
    // MARK: - Main Content View
    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header is pinned at the top
            headerSection
            // Use reliable safe area helper for consistent positioning across all devices
                .safeAreaHeader()
                .background(AppColors.background(for: themeManager.isDarkMode))
                .zIndex(10)
            
            // Video cards section with fixed minimum height to prevent header collapse
            videoCardSection
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
            Text("video.videoSeries".localized)
                .adaptiveFont(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                .adaptivePadding(1.0)
                .verticalSectionSpacing(0.5) // Consistent gap below title
            
            // Video series row: video series thumbnails and trash icon
            HStack(alignment: .center, spacing: DeviceInfo.shared.screenSize.horizontalPadding) {
                // Video series conveyor (thumbnails row)
                ScrollView(.horizontal, showsIndicators: false) {
                    videoSeriesRow
                        .padding(.leading, DeviceInfo.shared.screenSize.horizontalPadding)
                        .padding(.vertical, DeviceInfo.shared.spacing(0.2))
                }
                // Trash icon and label, vertically centered with video series row
                VStack(spacing: DeviceInfo.shared.spacing(0.3)) {
                    Button(action: {
                        print("🗑️ Video trash button pressed")
                        // Handle video trash action
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
                            if !videoManager.getTrashedVideos().isEmpty {
                                Text("\(videoManager.getTrashedVideos().count)")
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
            .verticalSectionSpacing(0.5) // Consistent gap below video series row
            
            // Progress Counter (processed / total) with progress bar
            let processed = videoManager.videos.filter({ $0.isReviewed }).count
            let total = videoManager.videos.count
            VStack(spacing: DeviceInfo.shared.spacing(0.2)) {
                HStack {
                    Text("video.videosProcessed".localized(with: processed, total))
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
    
    // Add this new computed property for the video series row
    @ViewBuilder
    private var videoSeriesRow: some View {
        if videoManager.isLoading || videoManager.videoSeries.isEmpty {
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
                ForEach(Array(videoManager.videoSeries.enumerated()), id: \.offset) { _, series in
                    VStack(spacing: DeviceInfo.shared.spacing(0.3)) {
                        VideoSeriesCircle(
                            series: series,
                            videoManager: videoManager,
                            onTap: {
                                print("📱 Video series tapped: \(series.count) videos")
                                // Handle video series tap
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Video Series Circle Component
    /// A circular view displaying video series similar to StoryCircle
    struct VideoSeriesCircle: View {
        @EnvironmentObject var themeManager: ThemeManager
        let series: [Video]
        let videoManager: VideoManager
        let onTap: () -> Void
        
        /// Whether series contains at least one favourite video
        private var hasFavourite: Bool {
            series.contains { $0.isFavorite }
        }
        
        /// Responsive sizing for different device types
        private var circleSize: CGFloat {
            UIDevice.current.userInterfaceIdiom == .pad ? 95 : 75
        }
        
        private var frameWidth: CGFloat {
            UIDevice.current.userInterfaceIdiom == .pad ? 100 : 78
        }
        
        /// Use the first video as thumbnail
        private var thumbnailVideo: Video? {
            series.first
        }
        
        var body: some View {
            VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 8 : 4) {
                Button(action: onTap) {
                    // Video thumbnail fills entire outer frame with stroke overlay
                    Group {
                        if let video = thumbnailVideo {
                            SeamlessVideoView(
                                video: video,
                                targetSize: CGSize(width: circleSize, height: circleSize),
                                autoPlay: false
                            )
                        } else {
                            // Fallback placeholder
                            Circle()
                                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                                .overlay(
                                    Image(systemName: "video.fill")
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                        .font(.system(size: circleSize * 0.3))
                                )
                        }
                    }
                    .frame(width: circleSize, height: circleSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                AppColors.accent(for: themeManager.isDarkMode),
                                lineWidth: UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
                            )
                    )
                    .shadow(color: .purple.opacity(0.3), radius: UIDevice.current.userInterfaceIdiom == .pad ? 8 : 6, x: 0, y: 2)
                    .overlay(
                        Group {
                            if hasFavourite {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
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
                
                Text("video.seriesCount".localized(with: series.count))
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    .lineLimit(1)
                    .frame(width: frameWidth)
            }
        }
    }
    
    // MARK: - Permission View
    @ViewBuilder
    private var permissionView: some View {
        VStack(spacing: DeviceInfo.shared.spacing(2.5)) {
            Image(systemName: "video.slash")
                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 60))
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
            
            VStack(spacing: DeviceInfo.shared.spacing(1.2)) {
                Text("video.accessDenied".localized)
                    .adaptiveFont(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                
                Text("video.accessRequiredMessage".localized)
                    .adaptiveFont(.body)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, DeviceInfo.shared.spacing(2.5))
            }
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: DeviceInfo.shared.spacing(1.2)) {
                    Image(systemName: "gear")
                        .font(.system(size: DeviceInfo.shared.spacing(1.8), weight: .semibold))
                    Text("action.openSettings".localized)
                        .font(.system(size: DeviceInfo.shared.spacing(1.8), weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, DeviceInfo.shared.spacing(3.0))
                .padding(.vertical, DeviceInfo.shared.spacing(1.5))
                .background(
                    Capsule()
                        .fill(AppColors.accent(for: themeManager.isDarkMode))
                        .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(DeviceInfo.shared.spacing(2.5))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .constrainedToDevice(usePadding: false)
    }
    
    // MARK: - Loading View
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: DeviceInfo.shared.spacing(2.0)) {
            Image(systemName: "video.fill")
                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 60, weight: .light))
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                .opacity(0.8)
            
            Text("video.loading".localized)
                .adaptiveFont(.title)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                .multilineTextAlignment(.center)
            
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent(for: themeManager.isDarkMode)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background(for: themeManager.isDarkMode))
    }
    
    // MARK: - Empty State View
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: DeviceInfo.shared.spacing(2.5)) {
            Image(systemName: "video")
                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 60))
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
            
            VStack(spacing: DeviceInfo.shared.spacing(1.2)) {
                Text("video.noVideosFound".localized)
                    .adaptiveFont(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                
                Text("video.emptyLibraryMessage".localized)
                    .adaptiveFont(.body)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DeviceInfo.shared.spacing(2.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .constrainedToDevice(usePadding: false)
    }
    
    // MARK: - Video Card Section
    @ViewBuilder
    private var videoCardSection: some View {
        ZStack {
            if currentVideo == nil {
                VStack(spacing: 20) {
                    Image(systemName: "video.stack")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    
                    // Show a different message when the entire feed is empty vs. when the user has simply reached the end.
                    if videoManager.videos.isEmpty {
                        Text("video.noVideosFound".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        
                        Text("video.emptyLibraryMessage".localized)
                            .font(.body)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("video.noMoreVideos".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 500) // Ensure minimum height to prevent header collapse
            } else {
                // Video card with smooth loading animation
                videoCardView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var videoCardView: some View {
        if let video = currentVideo {
            ZStack {
                // Background cards for depth effect (Tinder-style)
                backgroundCardsView
                
                // Main card
                mainVideoCardView(video: video)
            }
            // Apply the fixed card size so the card does not dynamically resize
            .frame(width: cardSize.width, height: cardSize.height)
            // Feedback overlays
            .overlay(heartOverlay)
            // Enhanced Action Banner
            .overlay(alignment: .top) { actionBannerView }
        }
    }
    
    // MARK: - Background Cards View
    @ViewBuilder
    private var backgroundCardsView: some View {
        ForEach(backgroundCards.prefix(2), id: \.id) { bgVideo in
            if let index = backgroundCards.firstIndex(where: { $0.id == bgVideo.id }) {
                videoCardBackground(video: bgVideo, index: index)
            }
        }
    }
    
    @ViewBuilder
    private func videoCardBackground(video: Video, index: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                .shadow(color: AppColors.shadow(for: themeManager.isDarkMode).opacity(0.05), 
                        radius: 8, x: 0, y: 4)
            
            SeamlessVideoView(video: video, targetSize: cardSize, autoPlay: false)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .scaleEffect(0.95 - CGFloat(index) * 0.02)  // Progressive scaling for depth
        .offset(y: CGFloat(index + 1) * 8)  // Progressive offset for stacking effect
        .opacity(0.8 - Double(index) * 0.2)  // Progressive opacity for depth
        .zIndex(-Double(index + 1))
    }
    
    // MARK: - Main Video Card
    @ViewBuilder
    private func mainVideoCardView(video: Video) -> some View {
        ZStack {
            // Gradient backdrop
            gradientBackdrop
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            
            // Card with shadow
            cardWithShadow
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            
            // Video player with controlled autoplay
            SeamlessVideoView(video: video, targetSize: cardSize, autoPlay: isCurrentVideoPlaying && !isProcessingAction && !isTransitioning)
                .id("main-video-\(video.id)") // Force recreation when video changes
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                .transition(.opacity.combined(with: .scale))
            
            // Swipe indicators
            swipeIndicatorOverlay
            
            // Action buttons
            actionButtonsOverlay
            
            // Video controls overlay
            videoControlsOverlay
        }
        .rotationEffect(.degrees(dragRotation))
        .offset(x: dragOffset.width + idleOffset, y: dragOffset.height)
        .scaleEffect(videoScale)
        .opacity(videoOpacity)
        .gesture(swipeGesture)
        .highPriorityGesture(doubleTapGesture)
        .onTapGesture { if !isProcessingAction { handleTap(video: video) } }
        .onChange(of: video.id) { _, newVideoId in
            // Reset video playback state when video changes
            print("🎬 Video ID changed from previous to: \(newVideoId)")
            
            // Reset all states for new video
            isCurrentVideoPlaying = false  // Start paused, will be set to play later
            userPausedVideo = false        // Reset manual pause state for new video
            
            // Ensure video appears properly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isCurrentVideoPlaying = true
                print("▶️ Auto-starting new video: \(newVideoId)")
            }
        }
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
            .scaleEffect(max(0.95 - CGFloat(abs(dragOffset.width)) / 1000.0, 0.9))
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
    
    // MARK: - Swipe Indicators
    @ViewBuilder
    private var swipeIndicatorOverlay: some View {
        Group {
            if dragOffset.width < -50 {  // Show indicator earlier for better feedback
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
            } else if dragOffset.width > 50 {  // Show indicator earlier for better feedback
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
        .allowsHitTesting(false)
    }
    
    // Computed properties for indicator animations
    private var trashIndicatorOpacity: Double {
        Double(min(CGFloat(abs(dragOffset.width)) / 150.0, 1.0))
    }
    
    private var trashIndicatorScale: CGFloat {
        CGFloat(min(CGFloat(abs(dragOffset.width)) / 150.0, 1.2))
    }
    
    private var keepIndicatorOpacity: Double {
        Double(min(CGFloat(dragOffset.width) / 150.0, 1.0))
    }
    
    private var keepIndicatorScale: CGFloat {
        CGFloat(min(CGFloat(dragOffset.width) / 150.0, 1.2))
    }
    
    // MARK: - Action Buttons Overlay
    @ViewBuilder
    private var actionButtonsOverlay: some View {
        VStack {
            Spacer()
            HStack {
                // Trash button
                trashButton
                
                Spacer()
                
                // Favorite button
                favoriteButton
                
                Spacer()
                
                // Keep button
                keepButton
            }
            .padding(.horizontal, DeviceInfo.shared.screenSize.horizontalPadding * 2)
            .padding(.bottom, DeviceInfo.shared.screenSize.horizontalPadding)
            .scaleEffect(actionButtonsVisible ? 1.0 : 0.85)
            .opacity(actionButtonsVisible ? 1.0 : 0.0)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: actionButtonsVisible)
        }
    }
    
    private var trashButton: some View {
        Button(action: { 
            handleAction(.trash) 
        }) {
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
        let latestVideo = currentVideo.flatMap { cv in videoManager.videos.first(where: { $0.id == cv.id }) } ?? currentVideo
        Button(action: { toggleFavorite() }) {
            Image(systemName: (latestVideo?.isFavorite ?? false) ? "heart.fill" : "heart")
                .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title, weight: .semibold))
                .foregroundColor((latestVideo?.isFavorite ?? false) ? .red : AppColors.primaryText(for: themeManager.isDarkMode))
                .scaleEffect(favoriteIconScale)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: favoriteIconScale)
        }
        .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
        .disabled(isProcessingAction)
    }
    
    private var keepButton: some View {
        Button(action: { 
            handleAction(.keep) 
        }) {
            Image(systemName: "checkmark")
                .adaptiveFont(.title)
                .fontWeight(.semibold)
        }
        .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
        .disabled(isProcessingAction)
        .scaleEffect(dragOffset.width > 50 ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragOffset.width)
    }
    
    // MARK: - Video Controls Overlay
    @ViewBuilder
    private var videoControlsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                
                // Video duration indicator
                if let video = currentVideo {
                    VStack(spacing: 4) {
                        Text(formatDuration(video.duration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(12)
                        
                        Spacer()
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
            }
            
            // Center play/pause indicator (appears briefly when toggled)
            if !isCurrentVideoPlaying {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Image(systemName: "pause.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 80, height: 80)
                            )
                            .transition(.scale.combined(with: .opacity))
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Gesture Handlers
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
                    
                    // Pause video during active dragging for better performance
                    if abs(value.translation.width) > 50 && isCurrentVideoPlaying && !userPausedVideo {
                        isCurrentVideoPlaying = false
                        print("⏸️ Pausing video during drag")
                    }
                    
                    // Provide visual feedback for swipe directions
                    if abs(value.translation.width) > 30 {
                        videoOpacity = max(0.7, 1.0 - Double(abs(value.translation.width)) / 300.0)
                    } else {
                        videoOpacity = 1.0
                    }
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
                animateHeartPop()
                toggleFavorite()
            }
    }
    
    // MARK: - Heart Overlay
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
                        heartOverlayScale = 1.5
                        heartOverlayOpacity = 0.8
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            heartOverlayOpacity = 0.0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            showHeartOverlay = false
                            heartOverlayScale = 0.8
                        }
                    }
            }
        }
    }
    
    // MARK: - Action Banner View
    @ViewBuilder
    private var actionBannerView: some View {
        if showActionLabel {
            Button(action: {
                if lastAction != nil {
                    performUndo()
                }
            }) {
                HStack(spacing: DeviceInfo.shared.spacing(1.2)) {
                    Image(systemName: actionLabelIcon)
                        .font(.system(size: DeviceInfo.shared.spacing(2.0), weight: .bold))
                        .foregroundColor(actionBannerTextColor)
                        .scaleEffect(1.1)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    
                    Text(actionLabelText)
                        .font(.system(size: DeviceInfo.shared.spacing(1.6), weight: .heavy, design: .rounded))
                        .foregroundColor(actionBannerTextColor)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    
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
    
    private var actionBannerTextColor: Color {
        actionLabelText == "Undo" ? .white : (themeManager.isDarkMode ? .black : .white)
    }
    
    // MARK: - Setup Methods
    // MARK: - Video Initialization
    private func initializeVideoViewIfNeeded() {
        // Only initialize if we haven't done so and conditions are right
        guard !hasInitialized, 
                !videoManager.isLoading, 
                videoManager.hasPermission,
              !videoManager.videos.isEmpty,
              currentVideo == nil else { 
            print("⚠️ Skipping initialization - already initialized: \(hasInitialized), loading: \(videoManager.isLoading), has permission: \(videoManager.hasPermission), videos count: \(videoManager.videos.count), current video exists: \(currentVideo != nil)")
            return 
        }
        
        print("🎬 Initializing VideoView for the first time")
        hasInitialized = true
        setupInitialVideo()
        scheduleIdleBounce()
    }
    
    private func setupInitialVideo() {
        print("🎬 Setting up initial video")
        guard currentVideo == nil else { 
            print("⚠️ Current video already exists, skipping setup")
            return 
        }
        
        rebuildVideoQueue()
        
        if let first = videoQueue.first {
            print("🎬 Found first video: \(first.id)")
            
            // Set current video and remove it from the queue immediately
            currentVideo = first
            videoQueue.removeFirst() // Remove the current video from queue
            
            // Set next video from the remaining queue
            nextVideo = videoQueue.first
            updateBackgroundCards()
            preloadNextVideos()
            
            // Ensure video starts loading and playing immediately
            videoLoader.loadVideo(first, targetSize: cardSize)
            
            // Start video playback after a brief delay to ensure loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isCurrentVideoPlaying = true
                self.userPausedVideo = false  // Reset for new video
                print("▶️ Starting initial video playback: \(first.id)")
            }
        } else {
            print("❌ No videos found in queue")
        }
    }
    
    private func rebuildVideoQueue() {
        print("🔄 Rebuilding video queue")
        
        // First, get all available videos (not trashed)
        let allAvailableVideos = videoManager.videos.filter { !$0.isTrashed }
        print("📊 Total available videos (not trashed): \(allAvailableVideos.count)")
        
        // Try to get unprocessed videos first
        let unprocessedVideos = allAvailableVideos.filter { video in
            !video.isReviewed && !processedVideos.contains(video.id)
        }
        print("📊 Unprocessed videos: \(unprocessedVideos.count)")
        
        if unprocessedVideos.isEmpty {
            if allAvailableVideos.isEmpty {
                print("❌ No videos available at all")
                videoQueue = []
                return
            }
            
            print("⚠️ No unprocessed videos found, using all available videos")
            processedVideos.removeAll()
            videoQueue = allAvailableVideos.shuffled()
        } else {
            videoQueue = unprocessedVideos.shuffled()
        }
        
        print("📊 Final video queue size: \(videoQueue.count)")
        
        // Log first few videos in queue for debugging
        if !videoQueue.isEmpty {
            print("🎬 Next videos in queue:")
            for (index, video) in videoQueue.prefix(3).enumerated() {
                print("  \(index + 1). \(video.id.uuidString.prefix(8))")
            }
        }
        
        updateBackgroundCards()
    }
    
    private func updateBackgroundCards() {
        // Since current video is no longer in the queue, take first 2 videos from queue for background
        let desired = Array(videoQueue.prefix(2))
        
        if desired.map(\.id) != backgroundCards.map(\.id) {
            // Use smoother animation for background card updates
            withAnimation(.easeInOut(duration: 0.3)) {
                backgroundCards = desired
            }
            print("🎬 Updated background cards: \(desired.count) cards")
        }
    }
    
    private func preloadNextVideos() {
        // Since current video is no longer in queue, preload first 3 videos from queue
        let videosToPreload = Array(videoQueue.prefix(3))
        guard !videosToPreload.isEmpty else { return }
        
        videoLoader.preloadVideos(videosToPreload, targetSize: cardSize)
    }
    
    // MARK: - Action Handlers
    private func handleAction(_ action: VideoAction) {
        guard let video = currentVideo, !isProcessingAction else { 
            print("❌ Cannot handle action - no current video or already processing")
            return 
        }
        
        print("🎬 Handling action: \(action) for video: \(video.id)")
        
        SoundManager.playClick()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        idleBounceWorkItem?.cancel()
        isProcessingAction = true
        
        // Store action for undo BEFORE performing it
        lastAction = UndoAction(video: video, action: action, timestamp: Date())
        
        // Stop current video immediately
        isCurrentVideoPlaying = false
        
        // Perform the action on the video FIRST
        videoManager.performAction(action, on: video)
        
        // Show action banner
        showActionBanner(text: "Undo", icon: action == .trash ? "trash" : action == .favorite ? "heart.fill" : action == .superStar ? "star.fill" : "checkmark", direction: action == .trash ? .left : action == .favorite ? .down : action == .superStar ? .down : .right)
        
        // Animate card off screen and advance to next video
        animateActionAndAdvance(direction: action == .trash ? .left : action == .favorite ? .down : action == .superStar ? .down : .right)
        
        print("🔄 Action completed: \(action), Video: \(video.asset.localIdentifier)")
    }
    
    private func performUndo() {
        guard let undoAction = lastAction else {
            print("⚠️ No action to undo")
            return
        }
        
        print("🔄 Performing undo for action: \(undoAction.action)")
        
        // Reverse the action
        switch undoAction.action {
        case .trash:
            videoManager.performAction(.keep, on: undoAction.video) // Restore from trash by marking as kept
        case .favorite:
            videoManager.performAction(.keep, on: undoAction.video) // Remove favorite status
        case .keep:
            // For keep actions, we just restore the video to unreviewed state
            break
        case .superStar:
            videoManager.performAction(.keep, on: undoAction.video) // Remove super star status
        }
        
        // Stop current video and prepare for transition
        isCurrentVideoPlaying = false
        
        // Put current video back into the queue if it exists
        if let current = currentVideo {
            videoQueue.insert(current, at: 0)
        }
        
        // Remove the undone video from queue if it exists and set as current
        videoQueue.removeAll { $0.id == undoAction.video.id } // Remove duplicates
        processedVideos.remove(undoAction.video.id)
        
        // Set undone video as current video
        currentVideo = undoAction.video
        updateBackgroundCards()
        
        // Clear the last action
        lastAction = nil
        
        SoundManager.playClick()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // Smooth entrance without any scale animation to prevent flashing
        videoOpacity = 1.0 // Start fully opaque
        videoScale = 1.0 // Start at full size immediately
        
        // Start playing the restored video
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isCurrentVideoPlaying = true
            self.userPausedVideo = false  // Reset pause state for restored video
            print("▶️ Starting playback for restored video: \(undoAction.video.id)")
        }
        
        showActionBanner(text: "Undo", icon: "arrow.uturn.left", direction: .right)
        scheduleIdleBounce()
        print("✅ Undo completed successfully")
    }
    
    private func toggleFavorite() {
        guard let video = currentVideo, !isProcessingAction else { return }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        // Play sound feedback
        SoundManager.playClick()
        
        // Start animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            favoriteIconScale = 1.3
        }
        
        // Get the current favorite status before toggling
        let wasAlreadyFavorite = video.isFavorite
        
        // Perform the action without advancing the video
        videoManager.performAction(.favorite, on: video)
        
        // Reset scale after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.favoriteIconScale = 1.0
            }
        }
        
        // Log the correct status after toggling
        print(wasAlreadyFavorite ? "💔 Removed from favorites" : "⭐ Added to favorites")
    }
    
    private func handleTap(video: Video) {
        // Toggle play/pause like TikTok
        isCurrentVideoPlaying.toggle()
        userPausedVideo = !isCurrentVideoPlaying  // Track manual pause state
        print("📱 Video tapped - playing: \(isCurrentVideoPlaying), user paused: \(userPausedVideo)")
        
        // Provide haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func handleDragEnd(value: DragGesture.Value) {
        let horizontalThreshold: CGFloat = 100
        let velocityThreshold: CGFloat = 500
        let translation = value.translation
        let velocity = value.velocity
        
        print("🎬 Drag ended - translation: \(translation.width), velocity: \(velocity.width)")
        
        if abs(translation.width) > horizontalThreshold || abs(velocity.width) > velocityThreshold {
            if translation.width < 0 || velocity.width < -velocityThreshold {
                // Swipe left = trash
                print("🗑️ Swiping left to trash")
                isCurrentVideoPlaying = false  // Stop current video before action
                handleAction(.trash)
            } else {
                // Swipe right = keep
                print("✅ Swiping right to keep")
                isCurrentVideoPlaying = false  // Stop current video before action
                handleAction(.keep)
            }
        } else {
            // Snap back if threshold not met and resume video
            print("↩️ Snapping back - threshold not met (translation: \(abs(translation.width)), velocity: \(abs(velocity.width)))")
            withAnimation(snapBackSpringAnimation) {
                dragOffset = .zero
                dragRotation = 0
                videoOpacity = 1.0
            }
            // Resume video playback after snap back (only if not manually paused)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !self.userPausedVideo {
                    self.isCurrentVideoPlaying = true
                    print("▶️ Resuming video after snap back")
                }
            }
            scheduleIdleBounce()
        }
    }
    
    private func animateActionAndAdvance(direction: SwipeDirection) {
        var targetOffset: CGSize
        var targetRotation: Double = 0
        
        let throwMultiplier = max(1.0, CGFloat(abs(swipeVelocity)) / 500.0)
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
        
        // Animate card off screen with faster timing
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            dragOffset = targetOffset
            dragRotation = targetRotation
            videoOpacity = 0
            videoScale = 0.8
            actionButtonsVisible = false // Hide buttons during transition
        }
        
        // Advance to next video sooner for more seamless experience
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.advanceToNextVideo()
        }
    }
    
    private func advanceToNextVideo() {
        guard !isTransitioning else { 
            print("⚠️ Already transitioning, skipping advance")
            return 
        }
        isTransitioning = true
        
        print("🎬 Advancing to next video")
        
        // Process current video
        if let current = self.currentVideo {
            print("🔄 Processing video: \(current.id)")
            self.processedVideos.insert(current.id)
        }
        
        // Find next available video from queue (current video is already removed from queue)
        var nextVideo: Video?
        if !self.videoQueue.isEmpty {
            nextVideo = self.videoQueue.removeFirst() // Take and remove the next video
            print("🎬 Found next video in queue: \(nextVideo?.id.uuidString.prefix(8) ?? "nil")")
        } else {
            // Rebuild queue if empty
            print("🔄 Queue is empty, rebuilding video queue")
            self.rebuildVideoQueue()
            if !self.videoQueue.isEmpty {
                nextVideo = self.videoQueue.removeFirst()
                print("🎬 After rebuild, next video: \(nextVideo?.id.uuidString.prefix(8) ?? "nil")")
            }
        }
        
        if let next = nextVideo {
            print("🎬 Setting current video to: \(next.id)")
            
            // Pre-load the next video BEFORE making UI changes
            self.videoLoader.loadVideo(next, targetSize: self.cardSize)
            
            // Reset drag states and set new video with proper timing
            DispatchQueue.main.async {
                // Reset drag states immediately
                self.dragOffset = .zero
                self.dragRotation = 0
                self.swipeVelocity = 0
                
                // Set new video
                self.currentVideo = next
                
                // Update background cards and UI states
                self.updateBackgroundCards()
                self.preloadNextVideos()
                
                // Reset UI states for new video
                self.videoOpacity = 1.0
                self.videoScale = 1.0
                self.actionButtonsVisible = true
                self.isProcessingAction = false
                self.isTransitioning = false
                
                // Start video playback after UI is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isCurrentVideoPlaying = true
                    self.userPausedVideo = false
                    print("▶️ Starting playback for next video: \(next.id)")
                    
                    // Schedule idle bounce for new video
                    self.scheduleIdleBounce()
                }
            }
            
        } else {
            print("❌ No more videos available")
            self.currentVideo = nil
            self.isProcessingAction = false
            self.isTransitioning = false
            self.actionButtonsVisible = true
        }
        
        self.swipeCount += 1
        if self.swipeCount % 10 == 0 { 
            self.cleanupMemory() 
        }
    }
    
    private func cleanupMemory() {
        if processedVideos.count > 100 {
            processedVideos.removeAll()
        }
        videoLoader.clearCache()
    }
    
    // MARK: - Helper Methods
    private func animateHeartPop() {
        heartOverlayScale = 0.8
        heartOverlayOpacity = 1.0
        showHeartOverlay = true
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func showActionBanner(text: String, icon: String, direction: SwipeDirection = .right) {
        actionLabelText = text
        actionLabelIcon = icon
        actionDirection = direction
        actionBannerColor = getBannerColor(for: text)
        
        actionBannerScale = 0.6
        actionBannerOpacity = 0
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)) {
            showActionLabel = true
            actionBannerOpacity = 1.0
            actionBannerScale = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showActionLabel = false
                actionBannerOpacity = 0
                actionBannerScale = 0.8
                lastAction = nil
            }
        }
    }
    
    private func getBannerColor(for text: String) -> Color {
        return AppColors.accent(for: themeManager.isDarkMode)
    }
    
    private func scheduleIdleBounce() {
        idleBounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            performIdleBounceHint()
        }
        idleBounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }
    
    private func performIdleBounceHint() {
        withAnimation(.easeInOut(duration: 0.25)) {
            idleOffset = 12
        }
        
        withAnimation(.easeInOut(duration: 0.25).delay(0.25)) {
            idleOffset = 0
        }
    }
    
}

// MARK: - Supporting Types
// SwipeDirection is defined in OnboardingView.swift





 
