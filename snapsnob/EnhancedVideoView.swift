import SwiftUI
import Photos
import FirebaseAnalytics
import AVKit
import AVFoundation

// MARK: - Enhanced Video View with Seamless Transitions
/// TikTok-style video feed with perfect seamless transitions and zero flashing
struct EnhancedVideoView: View {
    @EnvironmentObject var videoManager: VideoManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var transitionManager: AdvancedVideoTransitionManager
    
    // Current video state
    @State private var currentVideo: Video?
    @State private var isCurrentVideoPlaying = true
    @State private var userPausedVideo = false
    @State private var hasInitialized = false
    
    // Gesture and animation states
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0
    @State private var isProcessingAction = false
    @State private var swipeVelocity: CGFloat = 0
    
    // Visual feedback states
    @State private var videoOpacity: Double = 1.0
    @State private var videoScale: CGFloat = 1.0
    @State private var actionButtonsVisible = true
    
    // Action banner states
    @State private var showActionLabel: Bool = false
    @State private var actionLabelText: String = ""
    @State private var actionLabelIcon: String = ""
    @State private var actionBannerColor: Color = .black
    
    // Heart animation for double-tap favorite
    @State private var showHeartOverlay: Bool = false
    @State private var heartOverlayScale: CGFloat = 0.8
    @State private var heartOverlayOpacity: Double = 0.0
    
    // Undo functionality
    @State private var lastAction: UndoAction? = nil
    
    private struct UndoAction {
        let video: Video
        let action: VideoAction
        let timestamp: Date
    }
    
    // Device-specific sizing
    private var cardSize: CGSize {
        let screenBounds = UIScreen.main.bounds
        let width = min(screenBounds.width * 0.9, 400)
        let height = width * 1.6 // 16:10 aspect ratio for modern videos
        return CGSize(width: width, height: height)
    }
    
    private var cardCornerRadius: CGFloat {
        DeviceInfo.shared.isIPad ? 24 : 20
    }
    
    init() {
        let screenBounds = UIScreen.main.bounds
        let width = min(screenBounds.width * 0.9, 400)
        let height = width * 1.6
        let targetSize = CGSize(width: width, height: height)
        
        self._transitionManager = StateObject(wrappedValue: AdvancedVideoTransitionManager(targetSize: targetSize))
    }
    
    var body: some View {
        Group {
            if DeviceInfo.shared.isIPad {
                mainContentView
            } else {
                NavigationView {
                    mainContentView
                }
                .navigationBarHidden(true)
                .navigationViewStyle(.stack)
            }
        }
        .onAppear {
            print("📱 EnhancedVideoView appeared")
            if !videoManager.isLoading && !hasInitialized {
                hasInitialized = true
                setupInitialVideo()
            }
        }
        .onChange(of: videoManager.isLoading) { _, isLoading in
            print("🔄 VideoManager loading state changed: \(isLoading)")
            if !isLoading && !hasInitialized {
                hasInitialized = true
                setupInitialVideo()
            }
        }
        .onChange(of: videoManager.videos) { _, newVideos in
            if !videoManager.isLoading && !hasInitialized {
                hasInitialized = true
                setupInitialVideo()
            }
            
            // Filter to get only available videos
            let availableVideos = newVideos.filter { video in
                !video.isReviewed && !video.isTrashed
            }
            
            updateVideoQueue()
            
            // Check if current video was deleted or became unavailable
            if let currentVideo = currentVideo {
                let currentVideoStillAvailable = availableVideos.contains(where: { $0.id == currentVideo.id })
                
                if !currentVideoStillAvailable {
                    print("⚠️ Current video is no longer available, transitioning to next")
                    // Current video was deleted or marked as reviewed/trashed, advance to next
                    if transitionManager.hasMoreVideos() && !isProcessingAction {
                        executeSeamlessTransition()
                    } else {
                        // No more videos available
                        print("❌ No more videos available")
                        self.currentVideo = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Main Content View
    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            if !videoManager.hasPermission {
                permissionView
            } else if videoManager.isLoading {
                loadingView
            } else if currentVideo == nil {
                emptyStateView
            } else {
                videoFeedView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background(for: themeManager.isDarkMode))
    }
    
    // MARK: - Video Feed View
    @ViewBuilder
    private var videoFeedView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.background(for: themeManager.isDarkMode),
                    AppColors.background(for: themeManager.isDarkMode).opacity(0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Main video content
            VStack(spacing: 0) {
                Spacer()
                
                // Video card with seamless transitions
                if let video = currentVideo {
                    mainVideoCard(video: video)
                }
                
                Spacer()
                
                // Action banner
                actionBannerView
                    .padding(.bottom, DeviceInfo.SafeAreaHelper.bottomInset + 20)
            }
            
            // Heart overlay for favorites
            heartOverlay
        }
        .constrainedToDevice(usePadding: false)
    }
    
    // MARK: - Main Video Card with Seamless Transitions
    @ViewBuilder
    private func mainVideoCard(video: Video) -> some View {
        ZStack {
            // Card background with subtle shadow
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                .shadow(
                    color: AppColors.shadow(for: themeManager.isDarkMode).opacity(0.15),
                    radius: 12, x: 0, y: 8
                )
            
            // Use the shared transition manager for seamless video display
            SeamlessVideoPlayerView(
                transitionManager: transitionManager,
                targetSize: cardSize,
                autoPlay: isCurrentVideoPlaying && !isProcessingAction
            )
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            
            // Swipe indicators
            swipeIndicatorOverlay
            
            // Action buttons overlay
            actionButtonsOverlay
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .rotationEffect(.degrees(dragRotation))
        .offset(x: dragOffset.width, y: dragOffset.height)
        .scaleEffect(videoScale)
        .opacity(videoOpacity)
        .gesture(swipeGesture)
        .highPriorityGesture(doubleTapGesture)
        .onTapGesture { 
            if !isProcessingAction { 
                handleTap(video: video) 
            } 
        }
    }
    
    // MARK: - Swipe Indicators
    @ViewBuilder
    private var swipeIndicatorOverlay: some View {
        ZStack {
            if dragOffset.width < -30 {  
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
            } else if dragOffset.width > 30 {  
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
    
    // Computed properties for smooth indicator animations
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
        if actionButtonsVisible {
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: DeviceInfo.shared.spacing(2.0)) {
                        // Favorite button
                        Button(action: toggleFavorite) {
                            Image(systemName: currentVideo?.isFavorite == true ? "heart.fill" : "heart")
                                .font(.system(size: DeviceInfo.shared.isIPad ? 32 : 28))
                                .foregroundColor(currentVideo?.isFavorite == true ? .red : .white)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                        .scaleEffect(showHeartOverlay ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showHeartOverlay)
                        
                        // Play/Pause button
                        Button(action: togglePlayback) {
                            Image(systemName: isCurrentVideoPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: DeviceInfo.shared.isIPad ? 28 : 24))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.trailing, 20)
                }
                Spacer()
            }
            .padding(.top, 20)
            .transition(.opacity.combined(with: .scale))
        }
    }
    
    // MARK: - Gesture Handlers
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isProcessingAction else { return }
                
                dragOffset = value.translation
                let velocity = value.velocity.width
                dragRotation = Double(value.translation.width) / 20.0 + Double(velocity) / 500.0
                dragRotation = max(-45, min(45, dragRotation))
                swipeVelocity = value.velocity.width
                
                // Visual feedback for swipe directions
                if abs(value.translation.width) > 30 {
                    videoOpacity = max(0.7, 1.0 - Double(abs(value.translation.width)) / 300.0)
                } else {
                    videoOpacity = 1.0
                }
            }
            .onEnded { value in
                guard !isProcessingAction else { return }
                handleDragEnd(value: value)
            }
    }
    
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                animateHeartPop()
                toggleFavorite()
            }
    }
    
    // MARK: - Action Handlers
    private func handleDragEnd(value: DragGesture.Value) {
        let threshold: CGFloat = 120
        let velocityThreshold: CGFloat = 300
        
        if abs(value.translation.width) > threshold || abs(value.velocity.width) > velocityThreshold {
            if value.translation.width > 0 {
                // Swiped right - keep video
                handleKeepAction()
            } else {
                // Swiped left - trash video
                handleTrashAction()
            }
        } else {
            // Return to center
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                resetDragState()
            }
        }
    }
    
    private func handleKeepAction() {
        guard let video = currentVideo else { return }
        
        isProcessingAction = true
        print("💚 Keeping video: \(video.id.uuidString.prefix(8))")
        
        // Add to favorites
        videoManager.performAction(.favorite, on: video)
        
        // Show action feedback
        showActionFeedback(
            text: "video.added_to_favorites".localized,
            icon: "heart.fill",
            color: .green
        )
        
        // Animate out and transition
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: UIScreen.main.bounds.width, height: 0)
            videoOpacity = 0
            videoScale = 0.8
        }
        
        // Execute seamless transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.executeSeamlessTransition()
        }
    }
    
    private func handleTrashAction() {
        guard let video = currentVideo else { return }
        
        isProcessingAction = true
        print("🗑️ Trashing video: \(video.id.uuidString.prefix(8))")
        
        // Move to trash
        videoManager.performAction(.trash, on: video)
        
        // Show action feedback
        showActionFeedback(
            text: "video.moved_to_trash".localized,
            icon: "trash.fill",
            color: .red
        )
        
        // Animate out and transition
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: -UIScreen.main.bounds.width, height: 0)
            videoOpacity = 0
            videoScale = 0.8
        }
        
        // Execute seamless transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.executeSeamlessTransition()
        }
    }
    
    private func executeSeamlessTransition() {
        print("🎬 Executing seamless transition")
        
        // Use the advanced transition manager for perfect transitions
        if transitionManager.transitionToNext() {
            // Update current video from transition manager
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let newVideo = self.transitionManager.currentVideo {
                    self.currentVideo = newVideo
                    
                    // Reset states
                    withAnimation(.easeInOut(duration: 0.4)) {
                        self.resetDragState()
                        self.videoOpacity = 1.0
                        self.videoScale = 1.0
                        self.actionButtonsVisible = true
                    }
                    
                    // Complete processing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isProcessingAction = false
                        print("✅ Seamless transition completed")
                    }
                }
            }
        } else {
            // Fallback to traditional transition if advanced manager fails
            advanceToNextVideoFallback()
        }
    }
    
    // MARK: - Utility Functions
    private func setupInitialVideo() {
        guard !videoManager.videos.isEmpty else { 
            print("⚠️ No videos in videoManager")
            return 
        }
        
        // Filter to get only available videos (like VideoView does)
        let availableVideos = videoManager.videos.filter { video in
            !video.isReviewed && !video.isTrashed
        }
        
        guard !availableVideos.isEmpty else {
            print("⚠️ No available videos (all are reviewed or trashed)")
            return
        }
        
        print("🎬 Setting up initial video with \(availableVideos.count) available videos (out of \(videoManager.videos.count) total)")
        
        // Initialize the advanced transition manager with available videos only
        transitionManager.initialize(with: availableVideos)
        
        // Set current video from transition manager
        currentVideo = transitionManager.currentVideo
        
        // Start with play state
        isCurrentVideoPlaying = true
        userPausedVideo = false
    }
    
    private func updateVideoQueue() {
        // Filter to get only available videos (like VideoView does)
        let availableVideos = videoManager.videos.filter { video in
            !video.isReviewed && !video.isTrashed
        }
        
        print("🔄 Updating video queue with \(availableVideos.count) available videos (out of \(videoManager.videos.count) total)")
        transitionManager.updateQueue(with: availableVideos)
    }
    
    private func getNextVideoFromManager() -> Video? {
        // Filter to get only available videos (like VideoView does)
        let availableVideos = videoManager.videos.filter { video in
            !video.isReviewed && !video.isTrashed
        }
        
        return availableVideos.first { video in
            currentVideo?.id != video.id
        }
    }
    
    private func advanceToNextVideoFallback() {
        // Traditional fallback transition
        guard let nextVideo = getNextVideoFromManager() else {
            isProcessingAction = false
            return
        }
        
        currentVideo = nextVideo
        
        withAnimation(.easeInOut(duration: 0.4)) {
            resetDragState()
            videoOpacity = 1.0
            videoScale = 1.0
            actionButtonsVisible = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isProcessingAction = false
        }
    }
    
    private func resetDragState() {
        dragOffset = .zero
        dragRotation = 0
        swipeVelocity = 0
    }
    
    private func handleTap(video: Video) {
        print("👆 Video tapped: \(video.id.uuidString.prefix(8))")
        togglePlayback()
    }
    
    private func togglePlayback() {
        userPausedVideo = isCurrentVideoPlaying
        isCurrentVideoPlaying.toggle()
        
        SoundManager.playClick()
        print(isCurrentVideoPlaying ? "▶️ Video resumed" : "⏸️ Video paused")
    }
    
    private func toggleFavorite() {
        guard let video = currentVideo else { return }
        videoManager.performAction(.favorite, on: video)
        SoundManager.playClick()
    }
    
    private func animateHeartPop() {
        showHeartOverlay = true
        SoundManager.playClick()
    }
    
    // MARK: - Visual Feedback
    private func showActionFeedback(text: String, icon: String, color: Color) {
        actionLabelText = text
        actionLabelIcon = icon
        actionBannerColor = color
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showActionLabel = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showActionLabel = false
            }
        }
    }
    
    // MARK: - UI Components
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
    
    @ViewBuilder
    private var actionBannerView: some View {
        if showActionLabel {
            HStack(spacing: DeviceInfo.shared.spacing(1.0)) {
                Image(systemName: actionLabelIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(actionLabelText)
                    .adaptiveFont(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, DeviceInfo.shared.spacing(2.0))
            .padding(.vertical, DeviceInfo.shared.spacing(1.0))
            .background(
                Capsule()
                    .fill(actionBannerColor)
                    .shadow(color: actionBannerColor.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // MARK: - Standard UI Views (Permission, Loading, Empty State)
    @ViewBuilder
    private var permissionView: some View {
        VStack(spacing: DeviceInfo.shared.spacing(2.5)) {
            Image(systemName: "lock.fill")
                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 60))
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
            
            VStack(spacing: DeviceInfo.shared.spacing(1.2)) {
                Text("video.permissionRequired".localized)
                    .adaptiveFont(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                
                Text("video.permissionMessage".localized)
                    .adaptiveFont(.body)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                videoManager.checkPermission()
                Analytics.logEvent("permission_requested", parameters: ["type": "photos"])
            }) {
                Text("video.grantPermission".localized)
                    .adaptiveFont(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DeviceInfo.shared.spacing(2.5))
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background(for: themeManager.isDarkMode))
    }
}

// MARK: - Seamless Video Player View
/// A view that uses a shared transition manager for seamless video playback
struct SeamlessVideoPlayerView: View {
    @ObservedObject var transitionManager: AdvancedVideoTransitionManager
    let targetSize: CGSize
    let autoPlay: Bool
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(width: targetSize.width, height: targetSize.height)
            
            // Thumbnail layer (always present for instant display)
            if let thumbnail = transitionManager.getCurrentThumbnail() {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: targetSize.width, height: targetSize.height)
                    .clipped()
                    .opacity(transitionManager.isReady && autoPlay ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: transitionManager.isReady && autoPlay)
            }
            
            // Video player layer
            if let player = transitionManager.getCurrentPlayer() {
                VideoPlayer(player: player)
                    .frame(width: targetSize.width, height: targetSize.height)
                    .opacity(transitionManager.isReady && autoPlay ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.15), value: transitionManager.isReady && autoPlay)
            }
        }
        .onChange(of: autoPlay) { _, shouldPlay in
            if transitionManager.isReady {
                if let player = transitionManager.getCurrentPlayer() {
                    if shouldPlay {
                        player.play()
                    } else {
                        player.pause()
                    }
                }
            }
        }
    }
}
