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
    @State private var photoOpacity: Double = 1.0
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
    
    private let storyDuration: Double = 4.0
    
    // MARK: - Spring Animation Configurations
    private var photoTransitionAnimation: Animation {
        .interpolatingSpring(stiffness: 400, damping: 30)
    }
    
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic overlay fade – fully transparent after ~200pt drag
                Color.black.opacity(1.0 - min(abs(dismissOffset.height) / 200.0, 1.0)).ignoresSafeArea()
                
                if photoSeries.photos.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Нет фото в серии")
                            .foregroundColor(.white)
                            .font(.headline)
                        
                        Button("Закрыть") {
                            print("❌ Closing empty story view")
                            onDismiss()
                        }
                        .foregroundColor(.blue)
                        .font(.headline)
                    }
                    .onAppear {
                        print("⚠️ Story view showing empty state - no photos in series")
                    }
                } else {
                    VStack(spacing: 0) {
                        // Progress bars - at the very top
                        HStack(spacing: 4) {
                            ForEach(0..<photoSeries.photos.count, id: \.self) { index in
                                ProgressView(value: progress[safe: index] ?? 0.0, total: 1.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                    .frame(height: 3)
                                    .background(Color.white.opacity(0.3))
                                    .clipShape(Capsule())
                                    .animation(index == currentPhotoIndex ? .linear(duration: 0.1) : .none, value: progress[safe: index] ?? 0.0)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        // Header - close and title
                        HStack {
                            Button(action: {
                                print("❌ Story dismissed by X button")
                                if !isDismissing {
                                    isDismissing = true
                                    stopTimer()
                                    applyAllActions()
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
                                Button("Готово") {
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
                        
                        // Photo container - takes most of the space
                        ZStack {
                            if let photo = currentPhoto {
                                ZStack {
                                    // Preload next photo underneath for smooth transitions
                                    if currentPhotoIndex + 1 < photoSeries.photos.count {
                                        let nextPhoto = photoSeries.photos[currentPhotoIndex + 1]
                                        OptimizedPhotoView(
                                            photo: nextPhoto,
                                            targetSize: CGSize(width: geometry.size.width, height: geometry.size.height * 0.7)
                                        )
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .clipped()
                                        .opacity(nextPhotoOpacity)
                                    }
                                    
                                    // Current photo with optimized loading
                                    OptimizedPhotoView(
                                        photo: photo,
                                        targetSize: CGSize(width: geometry.size.width, height: geometry.size.height * 0.7)
                                    )
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                                    .scaleEffect(photoScale)
                                    .offset(dragOffset)
                                    .opacity(photoOpacity)
                                    .transformEffect(cardTransform)
                                    .id(currentPhotoIndex) // Force UI update when index changes
                                    .onTapGesture(count: 2) {
                                        // Double tap for fullscreen
                                        print("🖼️ Double tap - opening fullscreen")
                                        pauseTimer()
                                        showingFullScreen = true
                                    }

                                    // Checkmark overlay for the keep animation
                                    if showCheckmark {
                                        Image(systemName: "checkmark.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 120, height: 120)
                                            .foregroundColor(.white)
                                            .shadow(radius: 10)
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
                            } else {
                                // Fallback for invalid index
                                Rectangle()
                                    .fill(Color.red.opacity(0.3))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .overlay(
                                        VStack {
                                            Text("Ошибка загрузки фото")
                                                .foregroundColor(.white)
                                                .font(.headline)
                                            Text("Индекс: \(currentPhotoIndex) из \(photoSeries.photos.count)")
                                                .foregroundColor(.white)
                                                .font(.caption)
                                        }
                                    )
                                    .onAppear {
                                        print("❌ Invalid photo index in story: \(currentPhotoIndex) of \(photoSeries.photos.count)")
                                    }
                            }
                            
                            // Edge tap areas for navigation (invisible overlay)
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
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1) // Give photo area priority
                        
                        Spacer(minLength: 20)
                        
                        // Action buttons - at the bottom
                        HStack(spacing: 40) {
                            Button(action: {
                                print("🗑️ Trash button pressed in story")
                                moveToTrash()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash.fill")
                                    Text("В корзину")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(AppColors.accent(for: themeManager.isDarkMode))
                                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                                        .overlay(
                                            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                                        )
                                )
                            }
                            .scaleEffect(isProcessingAction && swipeDirection == .left ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isProcessingAction)
                            
                            Button(action: {
                                print("💚 Keep button pressed in story")
                                keepPhoto()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "heart.fill")
                                    Text("Оставить")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(AppColors.primaryText(for: themeManager.isDarkMode).opacity(0.95))
                                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                                        .overlay(
                                            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                                        )
                                )
                            }
                            .scaleEffect(isProcessingAction && swipeDirection == .right ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isProcessingAction)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .offset(y: dismissOffset.height)
                    .opacity(1.0 - min(abs(dismissOffset.height) / 300.0, 1.0))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Only consider vertical drags
                                if abs(value.translation.height) > abs(value.translation.width) {
                                    dismissOffset = value.translation
                                }
                            }
                            .onEnded { value in
                                let translation = value.translation
                                let velocity = value.velocity // reuse existing extension
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
                                            applyAllActions()
                                            onDismiss()
                                        }
                                    }
                                } else {
                                    withAnimation(dismissAnimation) {
                                        dismissOffset = .zero
                                    }
                                }
                            }
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .background(Color.clear) // transparent root
        .onAppear {
            print("📱 Enhanced Story view appeared: \(photoSeries.title) with \(photoSeries.photos.count) photos")
            print("📊 Photo series data: ID=\(photoSeries.id), isViewed=\(photoSeries.isViewed)")
            if photoSeries.photos.isEmpty {
                print("⚠️ WARNING: Photo series has no photos!")
            } else {
                print("📸 First photo asset: \(photoSeries.photos[0].asset.localIdentifier)")
                preloadNextPhotos()
            }
            setupProgress()
            startTimer()
        }
        .onDisappear {
            print("📱 Enhanced Story view disappeared")
            stopTimer()
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
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
                // Fallback for nil photo
                Text("Ошибка загрузки фото")
                    .foregroundColor(.white)
                    .onAppear {
                        print("❌ Current photo is nil in story fullscreen - Index: \(currentPhotoIndex)")
                        showingFullScreen = false
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
    
    private func goToNextPhoto() {
        print("➡️ Going to next photo - current: \(currentPhotoIndex), total: \(photoSeries.photos.count)")
        if let currentPhoto = currentPhoto {
            print("📸 Current photo before change: \(currentPhoto.asset.localIdentifier)")
        }
        
        if currentPhotoIndex < photoSeries.photos.count - 1 {
            // Fill current progress bar immediately
            if progress.indices.contains(currentPhotoIndex) {
                progress[currentPhotoIndex] = 1.0
            }
            
            // INSTANT transition: no animation
            isTransitioning = false
            swipeDirection = .left
            photoOpacity = 1.0
            cardTransform = .identity
            currentPhotoIndex += 1
            resetPhotoState()
            preloadNextPhotos()
            // Reset progress for new photo
            if progress.indices.contains(currentPhotoIndex) {
                progress[currentPhotoIndex] = 0.0
            }
            startTimer()
        } else {
            print("✅ Story completed - auto advancing to end")
            if !isDismissing {
                isDismissing = true
                stopTimer()
                applyAllActions()
                onDismiss()
            }
        }
    }
    
    private func goToPreviousPhoto() {
        print("⬅️ Going to previous photo - current: \(currentPhotoIndex)")
        if let currentPhoto = currentPhoto {
            print("📸 Current photo before change: \(currentPhoto.asset.localIdentifier)")
        }
        
        if currentPhotoIndex > 0 {
            // Reset current progress
            if progress.indices.contains(currentPhotoIndex) {
                progress[currentPhotoIndex] = 0.0
            }
            // INSTANT transition: no animation
            isTransitioning = false
            swipeDirection = .right
            photoOpacity = 1.0
            cardTransform = .identity
            currentPhotoIndex -= 1
            resetPhotoState()
            // Reset progress for returned photo
            if progress.indices.contains(currentPhotoIndex) {
                progress[currentPhotoIndex] = 0.0
            }
            startTimer()
        } else {
            print("⬅️ Already at first photo")
            isTransitioning = false
            startTimer()
        }
    }
    
    private func moveToTrash() {
        guard let photo = currentPhoto else {
            print("❌ No current photo for trash action")
            return
        }
        print("🗑️ MOVE TO TRASH - Photo ID: \(currentPhotoIndex), Asset: \(photo.asset.localIdentifier), Series: \(photoSeries.title)")
        // Track the action
        photoActions[photo] = "trash"
        print("📊 Tracked trash action. Total actions: \(photoActions.count)")
        // Provide feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Immediately apply the action for better UX
        photoManager.moveToTrash(photo)
        print("🗑️ Photo immediately moved to trash")
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
    }
    
    private func keepPhoto() {
        guard let photo = currentPhoto else {
            print("❌ No current photo for keep action")
            return
        }
        
        print("💚 KEEP - Photo ID: \(currentPhotoIndex), Asset: \(photo.asset.localIdentifier), Series: \(photoSeries.title)")
        
        // Track the action
        photoActions[photo] = "keep"
        print("📊 Tracked keep action. Total actions: \(photoActions.count)")
        
        // Provide feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Mark as reviewed but NOT as favorite (keep just means don't trash)
        photoManager.markReviewed(photo)
        print("💚 Photo marked as reviewed (kept)")
        
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
    }
    
    private func applyAllActions() {
        print("📊 Applying all remaining actions for photo series - \(photoActions.count) actions tracked")
        
        // Count how many actions we haven't applied yet (only trash actions remain)
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
            // Keep actions don't need to be applied - photos are already kept
        }
        
        print("📊 Applied \(actionsApplied) remaining actions")
        
        // Mark series as viewed
        if let index = photoManager.photoSeries.firstIndex(where: { $0.id == photoSeries.id }) {
            photoManager.photoSeries[index].isViewed = true
            print("✅ Marked series as viewed: \(photoSeries.title)")
        } else {
            print("⚠️ Could not find series to mark as viewed: \(photoSeries.title)")
        }
    }
    
    private func performSwipeAnimation(_ direction: SwipeDirection, completion: @escaping () -> Void) {
        isTransitioning = true
        stopTimer()
        
        let exitOffset: CGFloat = direction == .left ? -UIScreen.main.bounds.width : UIScreen.main.bounds.width
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
            dragOffset = CGSize(width: exitOffset, height: 0)
            photoScale = 0.9
            photoOpacity = 0.0
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
