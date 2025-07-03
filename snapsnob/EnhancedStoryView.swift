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
    @State private var dismissOffset: CGSize = .zero
    
    private let storyDuration: Double = 4.0
    
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
                                    PhotoImageView(
                                        photo: photo,
                                        targetSize: CGSize(width: geometry.size.width, height: geometry.size.height * 0.7)
                                    )
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                                    .scaleEffect(photoScale)
                                    .offset(dragOffset)
                                    .opacity(photoOpacity)
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
                                            .transition(.opacity)
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
                                        .fill(AppColors.cardBackground(for: themeManager.isDarkMode).opacity(0.9))
                                )
                            }
                            
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
                                        .fill(AppColors.cardBackground(for: themeManager.isDarkMode).opacity(0.9))
                                )
                            }
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
                                    // Trigger dismiss
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        dismissOffset = CGSize(width: 0, height: translation.height > 0 ? 1000 : -1000)
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        if !isDismissing {
                                            isDismissing = true
                                            stopTimer()
                                            applyAllActions()
                                            onDismiss()
                                        }
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
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
            // Заполняем текущую полоску без анимации
            if progress.indices.contains(currentPhotoIndex) {
                progress[currentPhotoIndex] = 1.0
            }
            
            currentPhotoIndex += 1
            swipeDirection = .left
            
            print("➡️ Advanced to photo \(currentPhotoIndex)")
            
            if let newPhoto = currentPhoto {
                print("📸 New current photo: \(newPhoto.asset.localIdentifier)")
            }
            
            // Обнуляем прогресс следующего кадра перед стартом таймера
            if progress.indices.contains(currentPhotoIndex) {
                progress[currentPhotoIndex] = 0.0
            }

            // No entrance animation – just reset state and restart timer
            resetPhotoState()
            startTimer()
        } else {
            print("✅ Story completed - auto advancing to end")
            if !isDismissing {
                isDismissing = true
                stopTimer() // Stop timer before applying actions
                applyAllActions()
                onDismiss()
            } else {
                print("⚠️ Already dismissing - ignoring duplicate call")
            }
        }
    }
    
    private func goToPreviousPhoto() {
        print("⬅️ Going to previous photo - current: \(currentPhotoIndex)")
        if let currentPhoto = currentPhoto {
            print("📸 Current photo before change: \(currentPhoto.asset.localIdentifier)")
        }
        
        if currentPhotoIndex > 0 {
            // Сбрасываем прогресс текущего кадра без анимации
            if progress.indices.contains(currentPhotoIndex) {
                progress[currentPhotoIndex] = 0.0
            }

            // No entrance animation – just reset state, index will be updated below
            resetPhotoState()
            
            currentPhotoIndex -= 1
            swipeDirection = .right
            
            if let newPhoto = currentPhoto {
                print("📸 New current photo: \(newPhoto.asset.localIdentifier)")
            }
            
            // Сбрасываем прогресс после перехода назад
            if progress.indices.contains(currentPhotoIndex) {
                progress[currentPhotoIndex] = 0.0
            }
            print("⬅️ Went back to photo \(currentPhotoIndex)")
            startTimer()
        } else {
            print("⬅️ Already at first photo")
            // Still reset transition state even if we can't go back
            isTransitioning = false
            resetPhotoState()
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
        
        // Immediately apply the action for better UX
        photoManager.moveToTrash(photo)
        print("🗑️ Photo immediately moved to trash")
        
        // Auto advance to next photo with smooth animation
        stopTimer()
        swipeDirection = .left
        
        // New trash animation – photo shrinks and slides down as if "sucked" into trash
        withAnimation(.easeInOut(duration: 0.5)) {
            dragOffset = CGSize(width: 0, height: UIScreen.main.bounds.height)
            photoScale = 0.1
            photoOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.resetPhotoState()
            self.goToNextPhoto()
        }
    }
    
    private func keepPhoto() {
        guard let photo = currentPhoto else {
            print("❌ No current photo for keep action")
            return
        }
        
        print("💚 KEEP PHOTO - Photo ID: \(currentPhotoIndex), Asset: \(photo.asset.localIdentifier), Series: \(photoSeries.title)")
        
        // Track the action
        photoActions[photo] = "keep"
        print("📊 Tracked keep action. Total actions: \(photoActions.count)")
        
        // Immediately mark as reviewed so it counts towards progress
        photoManager.markReviewed(photo)
        print("💚 Photo marked as kept / reviewed")
        
        // Auto advance to next photo with smooth animation
        stopTimer()
        swipeDirection = .left
        
        // New keep animation – show checkmark overlay then advance
        withAnimation(.easeInOut(duration: 0.2)) {
            showCheckmark = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.showCheckmark = false
            }
            self.resetPhotoState()
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
        photoOpacity = 1.0
        swipeDirection = .none
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
