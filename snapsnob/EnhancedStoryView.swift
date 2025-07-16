import SwiftUI
import Photos

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct EnhancedStoryView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let photoSeries: PhotoSeriesData
    let photoManager: PhotoManager
    let onDismiss: () -> Void
    
    @State private var currentPhotoIndex = 0
    @State private var progress: [Double] = []
    @State private var timer: Timer?
    @State private var isPaused = false
    @State private var showingFullScreen = false
    @State private var dragOffset = CGSize.zero
    @State private var photoActions: [Photo: String] = [:] // Track actions: "trash" or "keep"
    @State private var isDismissing = false // Prevent multiple dismiss calls
    @State private var isTransitioning = false
    @State private var photoScale: CGFloat = 1.0
    // Removed standalone photoOpacity; we now use card opacities
    @State private var swipeDirection: SwipeDirection = .none
    @State private var showCheckmark = false
    @State private var showTrashOverlay = false // NEW: for trash action
    @State private var trashOverlayScale: CGFloat = 1.0 // NEW: for trash action
    @State private var dismissOffset: CGSize = .zero
    
    // MARK: - Enhanced Animation States
    @State private var cardTransform: CGAffineTransform = .identity
    @State private var actionAnimationScale: CGFloat = 1.0
    @State private var nextPhotoOpacity: Double = 0
    @State private var preloadedImages: [Int: UIImage] = [:]
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
    
    private let storyDuration: Double = 4.0
    
    // MARK: - Spring Animation Configurations
    private var photoTransitionAnimation: Animation {
        .interpolatingSpring(stiffness: 400, damping: 30)
    }
    
    // Use global app animations for consistency
    private var smoothTransitionAnimation: Animation { AppAnimations.cardTransition }
    
    private var actionAnimation: Animation {
        .interpolatingSpring(stiffness: 350, damping: 25)
    }
    
    private var dismissAnimation: Animation {
        .interpolatingSpring(stiffness: 300, damping: 28)
    }
    
    private enum SwipeDirection {
        case none, left, right
    }
    
    // Current photo computed property to ensure we always have the right photo
    private var currentPhoto: Photo? {
        guard currentPhotoIndex < photoSeries.photos.count else { return nil }
        return photoSeries.photos[currentPhotoIndex]
    }
    
    // Next photo computed property
    private var nextPhoto: Photo? {
        guard currentPhotoIndex + 1 < photoSeries.photos.count else { return nil }
        return photoSeries.photos[currentPhotoIndex + 1]
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background overlay
                backgroundOverlay
                
                if photoSeries.photos.isEmpty {
                    emptyStateView
                } else {
                    mainContentView(geometry: geometry)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .background(Color.clear)
        .onAppear(perform: onAppearAction)
        .onDisappear {
            print("📱 Enhanced Story view disappeared")
            stopTimer()
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            fullScreenPhotoView
        }
    }
    
    // MARK: - View Components
    
    private var backgroundOverlay: some View {
        Color.black.opacity(1.0 - min(abs(dismissOffset.height) / 200.0, 1.0))
            .ignoresSafeArea()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
                                Text("common.noPhotosInSeries".localized)
                .foregroundColor(.white)
                .font(.headline)
            
                            Button("action.close".localized) {
                print("❌ Closing empty story view")
                onDismiss()
            }
            .foregroundColor(.blue)
            .font(.headline)
        }
        .onAppear {
            print("⚠️ Story view showing empty state - no photos in series")
        }
    }
    
    @ViewBuilder
    private func mainContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Progress bars
            progressBarsView
            
            // Header
            headerView
            
            // Photo container
            photoContainerView(geometry: geometry)
            
            Spacer(minLength: 20)
            
            // Action buttons
            actionButtonsView
        }
        .offset(y: dismissOffset.height)
        .opacity(1.0 - min(abs(dismissOffset.height) / 300.0, 1.0))
        .gesture(dismissGesture)
    }
    
    private var progressBarsView: some View {
        HStack(spacing: 4) {
            ForEach(0..<photoSeries.photos.count, id: \.self) { index in
                ProgressView(value: progress[safe: index] ?? 0.0, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(height: 3)
                    .background(Color.white.opacity(0.3))
                    .clipShape(Capsule())
                    .animation(.none, value: progress[safe: index] ?? 0.0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                print("❌ Story dismissed by X button - early dismissal")
                if !isDismissing {
                    isDismissing = true
                    stopTimer()
                    handleEarlyDismissal()
                    onDismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Text(photoSeries.title)
                .foregroundColor(.white)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            if currentPhotoIndex == photoSeries.photos.count - 1 {
                Button("action.done".localized) {
                    print("✅ Story completed - Done button pressed")
                    if !isDismissing {
                        isDismissing = true
                        stopTimer()
                        applyAllActions()
                        onDismiss()
                    }
                }
                .foregroundColor(.white)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(width: 60)
            } else {
                Color.clear.frame(width: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func photoContainerView(geometry: GeometryProxy) -> some View {
        ZStack {
            // Next photo card (underneath)
            if let next = nextPhoto {
                photoCard(
                    photo: next,
                    geometry: geometry,
                    opacity: nextCardOpacity,
                    scale: nextCardScale,
                    offset: nextCardOffset,
                    showButtons: false,
                    isInteractive: false
                )
            }
            
            // Current photo card (on top)
            if let current = currentPhoto {
                photoCard(
                    photo: current,
                    geometry: geometry,
                    opacity: currentCardOpacity,
                    scale: currentCardScale,
                    offset: currentCardOffset,
                    showButtons: true,
                    isInteractive: true
                )
                .offset(x: cardDragOffset.width + dragOffset.width, y: cardDragOffset.height + dragOffset.height)
                .scaleEffect(photoScale)
                .rotationEffect(.degrees(Double(cardDragOffset.width / 10)), anchor: .bottom)
                .gesture(swipeGesture)
            }
            
            // Swipe indicators
            if isDragging {
                swipeIndicatorsView
            }
            
            // Edge tap areas
            edgeTapAreasView(geometry: geometry)
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }
    
    private var swipeIndicatorsView: some View {
        HStack {
            // Left swipe - Trash indicator
            if cardDragOffset.width < -20 {
                swipeIndicator(
                    icon: "trash.fill",
                    text: "common.toTrash".localized,
                    color: .red,
                    offset: cardDragOffset.width
                )
            }
            
            Spacer()
            
            // Right swipe - Keep indicator
            if cardDragOffset.width > 20 {
                swipeIndicator(
                    icon: "checkmark.circle.fill",
                    text: "common.keep".localized,
                    color: .green,
                    offset: cardDragOffset.width
                )
            }
        }
        .padding(.horizontal, 40)
    }
    
    @ViewBuilder
    private func swipeIndicator(icon: String, text: String, color: Color, offset: CGFloat) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(color)
            Text(text)
                .font(.headline)
                .foregroundColor(color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color, lineWidth: 3)
                )
        )
        .opacity(min(Double(abs(offset) / 100), 1.0))
        .scaleEffect(min(Double(abs(offset) / 150) + 0.8, 1.2))
    }
    
    private func edgeTapAreasView(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left edge - previous
            Rectangle()
                .fill(Color.clear)
                .frame(width: geometry.size.width * 0.3)
                .contentShape(Rectangle())
                .onTapGesture {
                    print("⬅️ Left edge tapped - previous photo")
                    if !isTransitioning {
                        stopTimer()
                        goToPreviousPhoto()
                    }
                }
            
            Spacer()
            
            // Right edge - next
            Rectangle()
                .fill(Color.clear)
                .frame(width: geometry.size.width * 0.3)
                .contentShape(Rectangle())
                .onTapGesture {
                    print("➡️ Right edge tapped - next photo")
                    if !isTransitioning {
                        stopTimer()
                        goToNextPhoto()
                    }
                }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 40) {
            Button(action: {
                print("🗑️ Trash button pressed in story")
                moveToTrash()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                    Text("common.toTrash".localized)
                }
                .foregroundColor(themeManager.isDarkMode ? .black : .white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    themeManager.isDarkMode ?
                        AnyView(Capsule().fill(Color.white)) :
                        AnyView(actionButtonBackground(for: .left))
                )
            }
            .scaleEffect(isProcessingAction && swipeDirection == .left ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isProcessingAction)
            
            Button(action: {
                print("💚 Keep button pressed in story")
                keepPhoto()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .foregroundColor(themeManager.isDarkMode ? AppColors.primaryText(for: false) : AppColors.primaryText(for: true))
                    Text("common.keep".localized)
                }
                .foregroundColor(themeManager.isDarkMode ? AppColors.primaryText(for: false) : AppColors.primaryText(for: true))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    themeManager.isDarkMode ?
                        AnyView(Capsule().fill(Color.white)) :
                        AnyView(actionButtonBackground(for: .right))
                )
            }
            .scaleEffect(isProcessingAction && swipeDirection == .right ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isProcessingAction)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .opacity(buttonsOpacity)
    }
    
    @ViewBuilder
    private func actionButtonBackground(for direction: SwipeDirection) -> some View {
        Capsule()
            .fill(direction == .left ? 
                AppColors.accent(for: themeManager.isDarkMode) : 
                AppColors.primaryText(for: themeManager.isDarkMode).opacity(0.95))
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
            .overlay(
                Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
    
    private var fullScreenPhotoView: some View {
        Group {
            if let photo = currentPhoto {
                FullScreenPhotoView(photo: photo, photoManager: photoManager) {
                    print("🖼️ Returning from fullscreen to story")
                    showingFullScreen = false
                    resumeTimer()
                }
                .onAppear {
                    print("🖼️ Opening fullscreen from story for photo: \(photo.asset.localIdentifier)")
                }
            } else {
                Text("common.errorLoadingPhoto".localized)
                    .foregroundColor(.white)
                    .onAppear {
                        print("❌ Current photo is nil in story fullscreen - Index: \(currentPhotoIndex)")
                        showingFullScreen = false
                    }
            }
        }
    }
    
    // MARK: - Gestures
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isTransitioning && !isProcessingAction {
                    cardDragOffset = value.translation
                    isDragging = true
                    
                    // Update opacity based on drag distance
                    let dragAmount = abs(value.translation.width)
                    withAnimation(.easeOut(duration: 0.1)) {
                        currentCardOpacity = 1.0 - min(dragAmount / 200, 0.5)
                    }
                }
            }
            .onEnded { value in
                if !isTransitioning && !isProcessingAction {
                    handleSwipe(value: value)
                }
            }
    }
    
    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only consider vertical drags
                if abs(value.translation.height) > abs(value.translation.width) {
                    dismissOffset = value.translation
                }
            }
            .onEnded { value in
                let translation = value.translation
                let velocity = value.velocity
                let threshold: CGFloat = 120
                let velocityThreshold: CGFloat = 800
                if abs(translation.height) > threshold || abs(velocity.height) > velocityThreshold {
                    // Trigger dismiss with spring animation
                    withAnimation(dismissAnimation) {
                        dismissOffset = CGSize(width: 0, height: translation.height > 0 ? 1000 : -1000)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if !isDismissing {
                            isDismissing = true
                            stopTimer()
                            handleEarlyDismissal()
                            onDismiss()
                        }
                    }
                } else {
                    withAnimation(dismissAnimation) {
                        dismissOffset = .zero
                    }
                }
            }
    }
    
    // MARK: - Actions
    
    private func onAppearAction() {
        print("📱 Enhanced Story view appeared: \(photoSeries.title) with \(photoSeries.photos.count) photos")
        print("📊 Photo series data: ID=\(photoSeries.id), isViewed=\(photoSeries.isViewed)")
        if photoSeries.photos.isEmpty {
            print("⚠️ WARNING: Photo series has no photos!")
        } else {
            print("📸 First photo asset: \(photoSeries.photos[0].asset.localIdentifier)")
            preloadNextPhotos()
            prepareNextCard()
        }
        setupProgress()
        startTimer()
    }
    
    // MARK: - Photo Card View
    @ViewBuilder
    private func photoCard(
        photo: Photo,
        geometry: GeometryProxy,
        opacity: Double,
        scale: CGFloat,
        offset: CGSize,
        showButtons: Bool,
        isInteractive: Bool
    ) -> some View {
        ZStack {
            // Photo - Using optimized photo view for better performance
            OptimizedPhotoView(
                photo: photo,
                targetSize: CGSize(width: geometry.size.width, height: geometry.size.height * 0.7)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .scaleEffect(scale)
            .offset(offset)
            .opacity(opacity)
            .allowsHitTesting(isInteractive)
            .onTapGesture(count: 2) {
                if isInteractive {
                    print("🖼️ Double tap - opening fullscreen")
                    pauseTimer()
                    showingFullScreen = true
                }
            }
            
            // Overlay animations (only on current card)
            if isInteractive {
                // Checkmark overlay for the keep animation
                if showCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                        .shadow(radius: 6)
                        .scaleEffect(actionAnimationScale)
                        .opacity(showCheckmark ? 1 : 0)
                        .animation(actionAnimation, value: showCheckmark)
                        .animation(actionAnimation, value: actionAnimationScale)
                }
                // Trash overlay for the trash animation
                if showTrashOverlay {
                    Image(systemName: "trash.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.red)
                        .shadow(radius: 10)
                        .scaleEffect(trashOverlayScale)
                        .opacity(showTrashOverlay ? 1 : 0)
                        .animation(actionAnimation, value: showTrashOverlay)
                        .animation(actionAnimation, value: trashOverlayScale)
                }
            }
        }
    }
    
    private func setupProgress() {
        progress = Array(repeating: 0.0, count: photoSeries.photos.count)
        // Ensure we start from photo 0
        currentPhotoIndex = 0
        print("📊 Progress setup for \(photoSeries.photos.count) photos. Starting at index \(currentPhotoIndex)")
        print("📊 Initial progress: \(progress)")
    }
    
    private func startTimer() {
        stopTimer() // Ensure no duplicate timers
        guard currentPhotoIndex < progress.count else {
            print("⏰ Cannot start timer - invalid photo index: \(currentPhotoIndex)")
            return
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if !self.isPaused && self.currentPhotoIndex < self.progress.count {
                self.progress[self.currentPhotoIndex] += 0.1 / self.storyDuration
                
                if self.progress[self.currentPhotoIndex] >= 1.0 {
                    self.progress[self.currentPhotoIndex] = 1.0
                    print("⏰ Timer completed for photo \(self.currentPhotoIndex) - auto advancing")
                    // Stop timer before advancing to prevent multiple calls
                    self.stopTimer()
                    self.goToNextPhoto()
                }
            }
        }
        print("⏰ Timer started for photo \(currentPhotoIndex) with progress: \(progress[currentPhotoIndex])")
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        print("⏰ Timer stopped")
    }
    
    private func pauseTimer() {
        isPaused = true
        print("⏸️ Timer paused")
    }
    
    private func resumeTimer() {
        isPaused = false
        print("▶️ Timer resumed")
    }
    
    // MARK: - Swipe Handling
    private func handleSwipe(value: DragGesture.Value) {
        let threshold: CGFloat = 100
        let velocity = value.velocity
        let translation = value.translation
        
        // Check if swipe is strong enough
        if abs(translation.width) > threshold || abs(velocity.width) > 500 {
            if translation.width < 0 {
                // Swipe left – instantly trash and advance
                self.isDragging = true // keep true to skip overlay animations
                self.cardDragOffset = .zero
                self.currentCardOpacity = 1.0
                self.moveToTrash()
                // Reset dragging state immediately after action
                self.isDragging = false
            } else {
                // Swipe right – instantly keep and advance
                self.isDragging = true
                self.cardDragOffset = .zero
                self.currentCardOpacity = 1.0
                self.keepPhoto()
                // Reset dragging state immediately after action
                self.isDragging = false
            }
        } else {
            // Return to center with no additional animation
            cardDragOffset = .zero
            currentCardOpacity = 1.0
            isDragging = false
        }
    }
    
    private func animateCardExit(direction: SwipeDirection, completion: @escaping () -> Void) {
        let exitOffset: CGFloat = direction == .left ? -UIScreen.main.bounds.width * 1.5 : UIScreen.main.bounds.width * 1.5
        
        withAnimation(.easeOut(duration: 0.3)) {
            cardDragOffset = CGSize(width: exitOffset, height: 100)
            currentCardOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.cardDragOffset = .zero
            self.isDragging = false
            completion()
        }
    }
    
    private func goToNextPhoto() {
        guard currentPhotoIndex < photoSeries.photos.count - 1 else {
            print("✅ Story completed - reached end naturally")
            if !isDismissing {
                isDismissing = true
                stopTimer()
                applyAllActions() // This completes the story and moves it to end
                onDismiss()
            }
            return
        }
        
        // Complete progress for current slide instantly
        if progress.indices.contains(currentPhotoIndex) {
            progress[currentPhotoIndex] = 1.0
        }

        isTransitioning = true
        
        // Advance index instantly
        currentPhotoIndex += 1
        resetPhotoState()
        prepareNextCard()
        
        // Reset progress for new slide
        if progress.indices.contains(currentPhotoIndex) {
            progress[currentPhotoIndex] = 0.0
        }
        
        preloadNextPhotos()
        startTimer()
        isTransitioning = false
    }
    
    private func goToPreviousPhoto() {
        guard currentPhotoIndex > 0 else {
            print("⬅️ Already at first photo")
            startTimer()
            return
        }
        
        // Reset progress for current slide
        if progress.indices.contains(currentPhotoIndex) {
            progress[currentPhotoIndex] = 0.0
        }

        isTransitioning = true
        
        // Move index back instantly
        currentPhotoIndex -= 1
        resetPhotoState()
        prepareNextCard()
        
        // Ensure progress for new slide starts at 0
        if progress.indices.contains(currentPhotoIndex) {
            progress[currentPhotoIndex] = 0.0
        }
        
        preloadNextPhotos()
        startTimer()
        isTransitioning = false
    }
    
    private func moveToTrash() {
        guard let photo = currentPhoto else {
            print("❌ No current photo for trash action")
            return
        }
        print("🗑️ MOVE TO TRASH - Photo ID: \(currentPhotoIndex), Asset: \(photo.asset.localIdentifier), Series: \(photoSeries.title)")
        // Track the action locally and in PhotoManager
        photoActions[photo] = "trash"
        photoManager.markStoryInteraction(photo, interaction: "trash")
        print("📊 Tracked trash action. Total actions: \(photoActions.count)")
        // Provide feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Immediately apply the action for better UX
        photoManager.moveToTrash(photo)
        print("🗑️ Photo immediately moved to trash")
        
        // If not already animating (from swipe), show overlay
        if !isDragging {
            // Show trash overlay with spring pop
            stopTimer()
            swipeDirection = .left
            isProcessingAction = true
            trashOverlayScale = 0.5
            showTrashOverlay = true
            withAnimation(actionAnimation) {
                trashOverlayScale = 1.2
            }
            // Scale back to normal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(self.actionAnimation) {
                    self.trashOverlayScale = 1.0
                }
            }
            // Hide overlay and advance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.showTrashOverlay = false
                }
                self.isProcessingAction = false
                self.goToNextPhoto()
            }
        } else {
            // Called from swipe - just advance
            self.isProcessingAction = false
            self.goToNextPhoto()
        }
    }
    
    private func keepPhoto() {
        guard let photo = currentPhoto else {
            print("❌ No current photo for keep action")
            return
        }
        
        print("💚 KEEP - Photo ID: \(currentPhotoIndex), Asset: \(photo.asset.localIdentifier), Series: \(photoSeries.title)")
        
        // Track the action locally and in PhotoManager
        photoActions[photo] = "keep"
        photoManager.markStoryInteraction(photo, interaction: "keep")
        print("📊 Tracked keep action. Total actions: \(photoActions.count)")
        
        // Provide feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Don't mark as reviewed immediately - this will be done when story is completed
        print("💚 Photo marked for keeping in story (will be reviewed when story completes)")
        
        // If not already animating (from swipe), show overlay
        if !isDragging {
            // Show checkmark animation with spring physics
            stopTimer()
            swipeDirection = .right
            isProcessingAction = true
            
            // Reset scale first
            actionAnimationScale = 0.5
            showCheckmark = true
            
            // Animate checkmark appearance
            withAnimation(actionAnimation) {
                actionAnimationScale = 1.2
            }
            
            // Then scale back to normal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(self.actionAnimation) {
                    self.actionAnimationScale = 1.0
                }
            }
            
            // Hide checkmark and advance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.showCheckmark = false
                }
                self.isProcessingAction = false
                self.goToNextPhoto()
            }
        } else {
            // Called from swipe - just advance
            self.isProcessingAction = false
            self.goToNextPhoto()
        }
    }
    
    private func applyAllActions() {
        print("📊 Finalizing story series - \(photoActions.count) actions tracked")
        
        // Apply any remaining trash actions that weren't applied immediately
        var actionsApplied = 0
        for (photo, action) in photoActions {
            if action == "trash" {
                // Check if photo hasn't been moved to trash yet
                if !(photoManager.allPhotos.first(where: { $0.id == photo.id })?.isTrashed ?? false) {
                    print("🗑️ Applying remaining trash action for photo: \(photo.asset.localIdentifier)")
                    photoManager.moveToTrash(photo)
                    actionsApplied += 1
                }
            }
        }
        
        print("📊 Applied \(actionsApplied) remaining trash actions")
        
        // Complete the story series - this will mark keep actions as reviewed and move story to end
        photoManager.completeStorySeries(photoSeries.id)
        print("✅ Story series completion handled by PhotoManager")
    }
    
    private func handleEarlyDismissal() {
        print("📊 Handling early story dismissal - clearing interactions")
        
        // Apply any remaining trash actions that weren't applied immediately
        var actionsApplied = 0
        for (photo, action) in photoActions {
            if action == "trash" {
                // Check if photo hasn't been moved to trash yet
                if !(photoManager.allPhotos.first(where: { $0.id == photo.id })?.isTrashed ?? false) {
                    print("🗑️ Applying remaining trash action for photo: \(photo.asset.localIdentifier)")
                    photoManager.moveToTrash(photo)
                    actionsApplied += 1
                }
            }
        }
        
        print("📊 Applied \(actionsApplied) remaining trash actions")
        
        // Clear story interactions since user didn't complete the story
        photoManager.clearStoryInteractions(for: photoSeries.id)
        print("🧹 Cleared story interactions due to early dismissal")
    }
    
    private func performSwipeAnimation(_ direction: SwipeDirection, completion: @escaping () -> Void) {
        isTransitioning = true
        stopTimer()
        
        let exitOffset: CGFloat = direction == .left ? -UIScreen.main.bounds.width : UIScreen.main.bounds.width
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
            dragOffset = CGSize(width: exitOffset, height: 0)
            photoScale = 0.9
            // Removed photoOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            completion()
        }
    }
    
    private func performTapFeedback(_ direction: SwipeDirection, completion: @escaping () -> Void) {
        isTransitioning = true
        stopTimer()
        
        let feedbackOffset: CGFloat = direction == .left ? -30 : 30
        
        // Quick feedback animation
        withAnimation(.easeOut(duration: 0.1)) {
            dragOffset = CGSize(width: feedbackOffset, height: 0)
            photoScale = 0.98
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.15)) {
                dragOffset = .zero
                photoScale = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                completion()
            }
        }
    }
    
    private func resetPhotoState() {
        dragOffset = .zero
        photoScale = 1.0
        swipeDirection = .none
    }
    
    // MARK: - Photo Preloading
    private func preloadNextPhotos() {
        // Preload next 3 photos for smooth transitions
        let preloadCount = 3
        let startIndex = currentPhotoIndex + 1
        let endIndex = min(startIndex + preloadCount, photoSeries.photos.count)
        
        guard startIndex < endIndex else { return }
        
        let photosToPreload = Array(photoSeries.photos[startIndex..<endIndex])
        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.7)
        
        // Use PhotoManager's prefetch functionality
        photoManager.prefetchThumbnails(for: photosToPreload, targetSize: targetSize)
    }
    
    // NEW: Prepare next card for smooth transition
    private func prepareNextCard() {
        if nextPhoto != nil && currentPhotoIndex + 1 < photoSeries.photos.count {
            nextCardOpacity = 0.8 // Static underlay appearance
            nextCardScale = 0.95
            nextCardOffset = CGSize(width: 0, height: 10)
        } else {
            nextCardOpacity = 0.0
        }
    }
}

#Preview {
    let mockPhotoManager = PhotoManager()
    let mockPhoto = Photo(asset: PHAsset(), dateAdded: Date())
    let mockSeries = PhotoSeriesData(
        photos: [mockPhoto, mockPhoto, mockPhoto],
        thumbnailPhoto: mockPhoto,
        title: "Природа"
    )
    
    EnhancedStoryView(
        photoSeries: mockSeries,
        photoManager: mockPhotoManager
    ) {
        // Dismiss action
        print("📱 Preview story dismissed")
    }
}
