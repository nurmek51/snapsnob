import SwiftUI
import Photos

// MARK: - Home View
/// The main feed view showing single photos and story series
struct HomeView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var aiAnalysisManager: AIAnalysisManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedPhoto: Photo?
    @State private var showingFullScreen = false
    @State private var selectedSeries: PhotoSeriesData?
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
        let base = DeviceInfo.shared.cardSize()
        let availableWidth = UIScreen.main.bounds.width - DeviceInfo.shared.screenSize.horizontalPadding * 2
        let widenedWidth = min(base.width * 1.05, availableWidth)
        // Make the card noticeably taller for a more immersive photo view
        let heightenedHeight = base.height * 1.25
        return CGSize(width: widenedWidth, height: heightenedHeight)
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
            // Keep current card if it is still valid, otherwise reload feed.
            // We intentionally avoid resetting the whole feed on **every** update because
            // that may interrupt the swipe animation pipeline (e.g. after a photo was
            // moved to trash). Instead we only reload when the current index became
            // invalid or when there is no currently displayed photo.
            print("📱 Non-series photos changed → \(photoManager.nonSeriesPhotos.count) items")

            // If there are no photos left – simply clear current/next so the placeholder is shown.
            guard !photoManager.nonSeriesPhotos.isEmpty else {
                currentPhoto = nil
                nextPhoto = nil
                return
            }

            loadCurrentPhoto()
            prefetchNextPhoto()
        }
        .sheet(isPresented: $showingTrash) {
            TrashView(photoManager: photoManager)
        }
        .overlay {
            if showingFullScreen {
                fullScreenPhotoContent
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .overlay {
            if let series = selectedSeries {
                EnhancedStoryView(
                    photoSeries: series,
                    photoManager: photoManager
                ) {
                    print("📱 Story view dismissed")
                    withAnimation(AppAnimations.modal) {
                        self.selectedSeries = nil
                    }
                }
                .transition(.opacity)
                .zIndex(200)
                .onAppear {
                    print("📱 Opening story view for series: \(series.title) with \(series.photos.count) photos")
                }
            }
        }
        .fullScreenCover(isPresented: $showingAIAnalysis) {
            AIAnalysisView {
                showingAIAnalysis = false
            }
            .environmentObject(photoManager)
            .environmentObject(aiAnalysisManager)
        }
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
                // Reduced top padding to bring the header closer to the safe-area like Instagram
                .padding(.top, DeviceInfo.shared.spacing(0.5))
                .background(AppColors.background(for: themeManager.isDarkMode))
                .zIndex(10)
            
            // Photo cards section with fixed minimum height to prevent header collapse
            photoCardSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 4) // minimal gap after header
        }
        // Fixed bottom padding equal to Plus horizontal padding so spacing matches across iPhones
        .padding(.bottom, DeviceInfo.ScreenSize.plus.horizontalPadding)
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
            
            HStack(alignment: .top, spacing: 0) {
                // Stories Row - Conveyor style (full width like Instagram)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DeviceInfo.shared.screenSize.gridSpacing) {
                        ForEach(Array(photoManager.photoSeries.enumerated()), id: \.offset) { index, series in
                            StoryCircle(
                                series: series,
                                photoManager: photoManager,
                                isViewed: series.isViewed
                            ) {
                                print("📱 Story tapped: \(series.title)")
                                withAnimation(AppAnimations.modal) {
                                    selectedSeries = series
                                }
                            }
                        }
                    }
                    .padding(.leading, DeviceInfo.shared.screenSize.horizontalPadding)
                    .padding(.trailing, DeviceInfo.shared.screenSize.horizontalPadding * 5) // Extra trailing padding to account for trash icon
                }
                .padding(.trailing, 0) // Remove any trailing padding from ScrollView
                
                // Trash icon with badge - positioned absolutely
                VStack(spacing: 6) {
                    Button(action: {
                        print("🗑️ Trash button pressed")
                        showingTrash = true
                    }) {
                        ZStack {
                            // Transparent background like story circles
                            Circle()
                                .fill(Color.clear)
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
                .padding(.trailing, DeviceInfo.shared.screenSize.horizontalPadding)
                .zIndex(1) // Ensure trash icon is above stories
            }

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
                // Background card with border and shadow
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                    .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 8, x: 0, y: 4)
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
            .offset(dragOffset)
            .rotationEffect(.degrees(dragRotation))
            .onTapGesture {
                if !isProcessingAction {
                    handleTap(photo: photo)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isProcessingAction {
                            dragOffset = value.translation
                            dragRotation = Double(value.translation.width / 20)
                        }
                    }
                    .onEnded { value in
                        if !isProcessingAction {
                            handleDragEnd(value: value)
                        }
                    }
            )
            // Apply the fixed card size so the card does not dynamically resize
            .frame(width: cardSize.width, height: cardSize.height)
        }
    }
    
    @ViewBuilder
    private var fullScreenPhotoContent: some View {
        if let photo = selectedPhoto {
            FullScreenPhotoView(photo: photo, photoManager: photoManager) {
                print("🖼️ Dismissing fullscreen photo view")
                withAnimation(AppAnimations.modal) {
                    showingFullScreen = false
                    selectedPhoto = nil
                }
            }
            .onAppear {
                print("🖼️ HomeView: FullScreenPhotoView onAppear for photo: \(photo.asset.localIdentifier)")
            }
        } else {
            VStack {
                Text("Error: No photo selected")
                    .foregroundColor(.white)
                Button("Close") {
                    withAnimation(AppAnimations.modal) {
                        showingFullScreen = false
                    }
                }
                .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .onAppear {
                print("❌ HomeView: selectedPhoto is nil in fullScreenCover!")
            }
        }
    }
    
    // MARK: - Photo Loading Logic
    
    private func loadInitialPhotos() {
        guard !photoManager.nonSeriesPhotos.isEmpty else {
            currentPhoto = nil
            nextPhoto = nil
            return
        }

        loadCurrentPhoto()
        prefetchNextPhoto()
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
        
        currentPhoto = photo
        
        // Prefetch this photo for immediate display
        photoManager.prefetchThumbnails(for: [photo], targetSize: cardSize)
        
        // Animate in with smooth transition
        withAnimation(.easeOut(duration: 0.6)) {
            photoOpacity = 1.0
            photoScale = 1.0
        }
    }
    
    private func prefetchNextPhoto() {
        let remaining = photoManager.nonSeriesPhotos.filter { $0.id != currentPhoto?.id }
        guard let nextRandom = remaining.randomElement() else {
            nextPhoto = nil
            return
        }
        nextPhoto = nextRandom
        photoManager.prefetchThumbnails(for: [nextRandom], targetSize: cardSize)
    }
    
    private func advanceToNextPhoto() {
        guard !isTransitioning else { return }
        isTransitioning = true

        // Clean up cache for current photo
        if let current = currentPhoto {
            photoManager.stopPrefetchingThumbnails(for: [current], targetSize: cardSize)
        }

        loadCurrentPhoto()
        prefetchNextPhoto()
        isTransitioning = false
    }
    
    // MARK: - User Interactions
    
    enum PhotoAction {
        case trash, favorite, keep
    }
    
    private func handleAction(_ action: PhotoAction) {
        guard let photo = currentPhoto, !isProcessingAction else { return }
        
        isProcessingAction = true
        
        switch action {
        case .trash:
            print("🗑️ Moving photo to trash: \(photo.asset.localIdentifier)")
            photoManager.moveToTrash(photo)
            animateActionAndAdvance(direction: .left)
            
        case .favorite:
            print("💚 Toggling favorite for photo: \(photo.asset.localIdentifier)")
            photoManager.setFavorite(photo, isFavorite: !photo.isFavorite)
            // Consider the photo as "reviewed" so it won't appear again
            photoManager.markReviewed(photo)
            animateActionAndAdvance(direction: .down)
            
        case .keep:
            print("✅ Keeping photo: \(photo.asset.localIdentifier)")
            photoManager.markReviewed(photo)
            animateActionAndAdvance(direction: .right)
        }
    }
    
    private func handleTap(photo: Photo) {
        withAnimation(AppAnimations.modal) {
            selectedPhoto = photo
            showingFullScreen = true
        }
    }
    
    private func handleDragEnd(value: DragGesture.Value) {
        let threshold: CGFloat = 80
        let translation = value.translation
        
        if translation.width < -threshold {
            handleAction(.trash)
        } else if translation.width > threshold {
            handleAction(.keep)
        } else if translation.height > threshold {
            handleAction(.favorite)
        } else {
            // Reset position
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                dragOffset = .zero
                dragRotation = 0
            }
        }
    }
    
    private func animateActionAndAdvance(direction: SwipeDirection) {
        var targetOffset: CGSize
        var targetRotation: Double = 0
        
        switch direction {
        case .left:
            targetOffset = CGSize(width: -UIScreen.main.bounds.width, height: 0)
            targetRotation = -30
        case .right:
            targetOffset = CGSize(width: UIScreen.main.bounds.width, height: 0)
            targetRotation = 30
        case .down:
            targetOffset = CGSize(width: 0, height: UIScreen.main.bounds.height)
        }
        
        // Animate card exit (slide/rotate only, keep opacity to avoid blank frame)
        withAnimation(.easeIn(duration: 0.25)) {
            dragOffset = targetOffset
            dragRotation = targetRotation
        }
        
        // Advance to next photo right after exit animation finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            dragOffset = .zero
            dragRotation = 0
            isProcessingAction = false
            advanceToNextPhoto()
        }
    }
}

// MARK: - Supporting Types

enum SwipeDirection {
    case left, right, down
}

// Components have been moved to CommonUIComponents.swift

#Preview {
    HomeView()
}
