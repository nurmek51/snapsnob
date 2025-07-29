import SwiftUI
import Photos

// Video Series Data structure for story view
struct VideoSeriesData {
    let videos: [Video]
    let title: String
    let creationDate: Date
    
    init(videos: [Video]) {
        self.videos = videos
        self.title = "Video Series"
        self.creationDate = videos.first?.creationDate ?? Date()
    }
}

struct EnhancedVideoStoryView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let videoSeries: VideoSeriesData
    let videoManager: VideoManager
    let onDismiss: () -> Void
    
    @State private var currentVideoIndex = 0
    @State private var progress: [Double] = []
    @State private var timer: Timer?
    @State private var isPaused = false
    @State private var showingFullScreen = false
    @State private var dragOffset = CGSize.zero
    @State private var videoActions: [Video: String] = [:] // Track actions: "trash" or "keep"
    @State private var isDismissing = false // Prevent multiple dismiss calls
    @State private var isTransitioning = false
    @State private var videoScale: CGFloat = 1.0
    @State private var swipeDirection: SwipeDirection = .right
    @State private var showCheckmark = false
    @State private var showTrashOverlay = false
    @State private var trashOverlayScale: CGFloat = 1.0
    @State private var dismissOffset: CGSize = .zero
    
    // MARK: - Enhanced Animation States
    @State private var cardTransform: CGAffineTransform = .identity
    @State private var actionAnimationScale: CGFloat = 1.0
    @State private var nextVideoOpacity: Double = 0
    @State private var preloadedVideos: [Int: Video] = [:]
    @State private var isProcessingAction = false
    
    // NEW: Smooth transition states
    @State private var currentCardOpacity: Double = 1.0
    @State private var nextCardOpacity: Double = 0.0
    @State private var currentCardScale: CGFloat = 1.0
    @State private var nextCardScale: CGFloat = 0.95
    @State private var currentCardOffset: CGSize = .zero
    @State private var nextCardOffset: CGSize = CGSize(width: 0, height: 20)
    @State private var buttonsOpacity: Double = 1.0
    @State private var cardDragOffset: CGSize = .zero
    @State private var isDragging = false
    
    // Video-specific states
    @State private var isCurrentVideoPlaying = true
    @State private var videoLoader = SeamlessVideoLoader()
    
    private let videoDuration: TimeInterval = 5.0 // Auto-advance time per video
    private var smoothTransitionAnimation: Animation { AppAnimations.cardTransition }
    private var cardSize: CGSize { DeviceInfo.shared.cardSize() }
    
    var body: some View {
        ZStack {
            // Background
            AppColors.background(for: themeManager.isDarkMode)
                .ignoresSafeArea()
            
            if !isDismissing {
                VStack(spacing: 0) {
                    // Progress bars
                    progressBarsView
                    
                    // Main content
                    mainContentView
                    
                    // Action buttons
                    actionButtonsView
                }
                .offset(dismissOffset)
                .scaleEffect(1.0 - abs(dismissOffset.height) / 1000.0)
                .opacity(1.0 - abs(dismissOffset.height) / 800.0)
            }
        }
        .onAppear {
            setupStory()
        }
        .onDisappear {
            cleanupStory()
        }
        .gesture(dismissGesture)
    }
    
    // MARK: - Progress Bars View
    @ViewBuilder
    private var progressBarsView: some View {
        HStack(spacing: 4) {
            ForEach(0..<videoSeries.videos.count, id: \.self) { index in
                ProgressView(value: progress[safe: index] ?? 0.0, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .scaleEffect(y: 2.0)
                    .animation(.linear(duration: 0.1), value: progress[safe: index] ?? 0.0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
    }
    
    // MARK: - Main Content View
    @ViewBuilder
    private var mainContentView: some View {
        ZStack {
            // Current video
            if let currentVideo = videoSeries.videos[safe: currentVideoIndex] {
                videoContainerView(video: currentVideo, isMain: true)
                    .opacity(currentCardOpacity)
                    .scaleEffect(currentCardScale)
                    .offset(currentCardOffset)
                    .offset(cardDragOffset)
                    .zIndex(1)
            }
            
            // Next video (for smooth transitions)
            if let nextVideo = videoSeries.videos[safe: currentVideoIndex + 1] {
                videoContainerView(video: nextVideo, isMain: false)
                    .opacity(nextCardOpacity)
                    .scaleEffect(nextCardScale)
                    .offset(nextCardOffset)
                    .zIndex(0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(swipeGesture)
        .onTapGesture {
            handleTap()
        }
    }
    
    // MARK: - Video Container View
    @ViewBuilder
    private func videoContainerView(video: Video, isMain: Bool) -> some View {
        ZStack {
            // Video player
            SeamlessVideoView(
                video: video,
                targetSize: cardSize,
                autoPlay: isMain && isCurrentVideoPlaying && !isPaused
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
            
            // Overlay indicators
            if isMain {
                overlayView(for: video)
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
    }
    
    // MARK: - Overlay View
    @ViewBuilder
    private func overlayView(for video: Video) -> some View {
        ZStack {
            // Pause indicator
            if isPaused {
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
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Action overlays
            actionOverlaysView
        }
    }
    
    // MARK: - Action Overlays
    @ViewBuilder
    private var actionOverlaysView: some View {
        Group {
            // Trash overlay
            if showTrashOverlay {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                            .scaleEffect(trashOverlayScale)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: trashOverlayScale)
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Keep checkmark
            if showCheckmark {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .scaleEffect(actionAnimationScale)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: actionAnimationScale)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Action Buttons View
    @ViewBuilder
    private var actionButtonsView: some View {
        HStack(spacing: 40) {
            // Trash button
            Button(action: { handleAction(.trash) }) {
                Image(systemName: "xmark")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Circle())
            }
            .disabled(isProcessingAction)
            
            // Keep button
            Button(action: { handleAction(.keep) }) {
                Image(systemName: "checkmark")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.green.opacity(0.8))
                    .clipShape(Circle())
            }
            .disabled(isProcessingAction)
            
            // Favorite button
            Button(action: { handleAction(.favorite) }) {
                let isFavorite = videoSeries.videos[safe: currentVideoIndex]?.isFavorite ?? false
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(isFavorite ? .red : .white)
                    .frame(width: 60, height: 60)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .disabled(isProcessingAction)
        }
        .opacity(buttonsOpacity)
        .padding(.bottom, 50)
    }
    
    // MARK: - Gestures
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isProcessingAction else { return }
                
                isDragging = true
                cardDragOffset = value.translation
                
                // Visual feedback for swipe direction
                if value.translation.width > 50 {
                    // Swiping right (keep)
                    showCheckmark = true
                    showTrashOverlay = false
                } else if value.translation.width < -50 {
                    // Swiping left (trash)
                    showTrashOverlay = true
                    showCheckmark = false
                } else {
                    showCheckmark = false
                    showTrashOverlay = false
                }
            }
            .onEnded { value in
                guard !isProcessingAction else { return }
                
                isDragging = false
                
                let threshold: CGFloat = 80
                
                if value.translation.width > threshold {
                    handleAction(.keep)
                } else if value.translation.width < -threshold {
                    handleAction(.trash)
                } else {
                    // Snap back
                    withAnimation(AppAnimations.cardReset) {
                        cardDragOffset = .zero
                        showCheckmark = false
                        showTrashOverlay = false
                    }
                }
            }
    }
    
    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 50 {
                    dismissOffset = value.translation
                }
            }
            .onEnded { value in
                if value.translation.height > 150 {
                    dismiss()
                } else {
                    withAnimation(.spring()) {
                        dismissOffset = .zero
                    }
                }
            }
    }
    
    // MARK: - Story Management
    private func setupStory() {
        progress = Array(repeating: 0.0, count: videoSeries.videos.count)
        startTimer()
        
        // Preload videos
        videoLoader.preloadVideos(Array(videoSeries.videos.prefix(3)), targetSize: cardSize)
    }
    
    private func cleanupStory() {
        timer?.invalidate()
        timer = nil
        videoLoader.clearCache()
    }
    
    private func startTimer() {
        timer?.invalidate()
        
        guard !isPaused, currentVideoIndex < videoSeries.videos.count else { return }
        
        let updateInterval: TimeInterval = 0.05
        let totalUpdates = Int(videoDuration / updateInterval)
        var currentUpdate = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            currentUpdate += 1
            let progressValue = Double(currentUpdate) / Double(totalUpdates)
            
            if currentVideoIndex < progress.count {
                progress[currentVideoIndex] = min(progressValue, 1.0)
            }
            
            if progressValue >= 1.0 {
                advanceToNextVideo()
            }
        }
    }
    
    private func handleTap() {
        isPaused.toggle()
        isCurrentVideoPlaying = !isPaused
        
        if isPaused {
            timer?.invalidate()
            timer = nil
        } else {
            startTimer()
        }
    }
    
    private func handleAction(_ action: VideoAction) {
        guard !isProcessingAction,
              let currentVideo = videoSeries.videos[safe: currentVideoIndex] else { return }
        
        isProcessingAction = true
        isPaused = true
        timer?.invalidate()
        timer = nil
        
        // Perform action
        videoManager.performAction(action, on: currentVideo)
        
        // Show action feedback
        switch action {
        case .trash:
            showTrashOverlay = true
            trashOverlayScale = 1.2
        case .keep:
            showCheckmark = true
            actionAnimationScale = 1.2
        case .favorite:
            // Just perform the action without advancing
            isProcessingAction = false
            isPaused = false
            startTimer()
            return
        case .superStar:
            // Handle super star action
            break
        }
        
        // Animate and advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.advanceToNextVideoWithAction()
        }
    }
    
    private func advanceToNextVideo() {
        guard !isTransitioning else { return }
        
        if currentVideoIndex >= videoSeries.videos.count - 1 {
            dismiss()
            return
        }
        
        isTransitioning = true
        
        withAnimation(smoothTransitionAnimation) {
            currentCardOpacity = 0
            currentCardScale = 0.8
            currentCardOffset = CGSize(width: -50, height: 0)
            
            nextCardOpacity = 1
            nextCardScale = 1.0
            nextCardOffset = .zero
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.currentVideoIndex += 1
            
            // Reset states
            self.currentCardOpacity = 1.0
            self.currentCardScale = 1.0
            self.currentCardOffset = .zero
            self.nextCardOpacity = 0.0
            self.nextCardScale = 0.95
            self.nextCardOffset = CGSize(width: 0, height: 20)
            
            self.isTransitioning = false
            self.isPaused = false
            self.startTimer()
        }
    }
    
    private func advanceToNextVideoWithAction() {
        withAnimation(AppAnimations.cardSwipe) {
            currentCardOpacity = 0
            currentCardScale = 0.8
            cardDragOffset = CGSize(width: showTrashOverlay ? -300 : 300, height: 0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.showTrashOverlay = false
            self.showCheckmark = false
            self.cardDragOffset = .zero
            self.trashOverlayScale = 1.0
            self.actionAnimationScale = 1.0
            
            if self.currentVideoIndex >= self.videoSeries.videos.count - 1 {
                self.dismiss()
            } else {
                self.currentVideoIndex += 1
                self.currentCardOpacity = 1.0
                self.currentCardScale = 1.0
                self.currentCardOffset = .zero
                
                self.isProcessingAction = false
                self.isPaused = false
                self.startTimer()
            }
        }
    }
    
    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        
        timer?.invalidate()
        timer = nil
        
        withAnimation(.easeInOut(duration: 0.3)) {
            dismissOffset = CGSize(width: 0, height: UIScreen.main.bounds.height)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.onDismiss()
        }
    }
} 