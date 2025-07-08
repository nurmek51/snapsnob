import SwiftUI
import Photos

struct AdaptivePhotoGrid: View {
    let photos: [Photo]
    let onPhotoTap: (Photo) -> Void
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: DeviceInfo.shared.screenSize.gridSpacing), count: DeviceInfo.shared.screenSize.gridColumns)
        let cellSize = DeviceInfo.shared.screenSize.horizontalPadding * 5
        LazyVGrid(columns: columns, spacing: DeviceInfo.shared.screenSize.gridSpacing) {
            ForEach(photos) { photo in
                ZStack {
                    PhotoImageView(
                        photo: photo,
                        targetSize: CGSize(width: cellSize * UIScreen.main.scale, height: cellSize * UIScreen.main.scale)
                    )
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: cellSize, height: cellSize)
                    .clipped()
                    .adaptiveCornerRadius()
                }
                .onTapGesture {
                    onPhotoTap(photo)
                }
            }
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var aiManager: AIAnalysisManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isRefreshing = false
    @State private var selectedPhoto: Photo?
    @State private var showingFullScreen = false
    @State private var expandedMonths: Set<String> = []
    @State private var showingThemeSelector = false
    @State private var isSwipeMode = false
    
    // Recent favourite photos (up to 6 most recent)
    private var topFavouritePhotos: [Photo] {
        // Break the chained calls into discrete steps for faster type-checking.
        let favourites = photoManager.displayPhotos.filter { $0.isFavorite }
        let sorted = favourites.sorted { $0.creationDate > $1.creationDate }
        let limited = Array(sorted.prefix(6))
        return limited
    }
    
    // Super star photos (Best of the Best)
    private var superStarPhotos: [Photo] {
        let superStars = photoManager.displayPhotos.filter { $0.isSuperStar }
        return superStars.sorted { $0.creationDate > $1.creationDate }
    }
    
    // Favourite photos grouped by month
    private var favouritesByMonth: [(month: String, photos: [Photo])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")

        // 1. Filter favourites
        let favourites = photoManager.displayPhotos.filter { $0.isFavorite }

        // 2. Group by month string
        let grouped = Dictionary(grouping: favourites) { photo in
            formatter.string(from: photo.creationDate)
        }

        // 3. Convert dictionary into array of tuples and sort photos inside each month
        var result: [(month: String, photos: [Photo])] = []
        for (key, value) in grouped {
            let sortedPhotos = value.sorted { $0.creationDate > $1.creationDate }
            result.append((month: key, photos: sortedPhotos))
        }

        // 4. Sort months (newest first) using parsed dates
        result.sort { first, second in
            guard
                let d1 = formatter.date(from: first.month),
                let d2 = formatter.date(from: second.month)
            else { return false }
            return d1 > d2
        }

        return result
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    dashboardSection
                    
                    if !superStarPhotos.isEmpty {
                        bestOfBestSection
                    }
                    
                    topFavoritesSection
                    
                    monthlyPhotosSection
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .constrainedToDevice(usePadding: false)
            .navigationTitle("Избранное")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        toggleTheme()
                    }) {
                        Image(systemName: themeIcon)
                            .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        refreshData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatCount(isRefreshing ? 10 : 0), value: isRefreshing)
                    }
                }
            }
            .fullScreenCover(item: Binding<Photo?>(
                get: { showingFullScreen ? selectedPhoto : nil },
                set: { newValue in
                    if newValue == nil {
                        withAnimation(AppAnimations.modal) {
                            showingFullScreen = false
                            selectedPhoto = nil
                        }
                    }
                })
            ) { photo in
                FullScreenPhotoView(photo: photo, photoManager: photoManager) {
                    withAnimation(AppAnimations.modal) {
                        showingFullScreen = false
                        selectedPhoto = nil
                    }
                }
            }
            .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
        }
        .navigationTitle("Избранное")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    toggleTheme()
                }) {
                    Image(systemName: themeIcon)
                        .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    refreshData()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(.linear(duration: 1).repeatCount(isRefreshing ? 10 : 0), value: isRefreshing)
                }
            }
        }
        .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Dashboard Section
    private var dashboardSection: some View {
        VStack(spacing: 16) {
            HStack {
                StatCard(title: "Всего фото", value: "\(photoManager.totalPhotosCount)", color: AppColors.accent(for: themeManager.isDarkMode))
                StatCard(title: "Избранные", value: "\(photoManager.favoritePhotosCount)", color: AppColors.secondaryText(for: themeManager.isDarkMode))
            }
            
            HStack {
                StatCard(title: "За неделю", value: "+\(photoManager.photosLastWeek)", color: AppColors.accent(for: themeManager.isDarkMode))
                StatCard(title: "Лучшие", value: "\(photoManager.superStarPhotosCount)", color: .yellow)
            }
            
            swipeModeToggle
        }
        .adaptivePadding()
    }
    
    // MARK: - Swipe Mode Toggle
    private var swipeModeToggle: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isSwipeMode.toggle()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSwipeMode ? "hand.draw.fill" : "hand.draw")
                    .adaptiveFont(.title)
                    .foregroundColor(isSwipeMode ? .white : AppColors.accent(for: themeManager.isDarkMode))
                
                Text(isSwipeMode ? "Обычный режим" : "Режим свайпа")
                    .adaptiveFont(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isSwipeMode ? .white : AppColors.primaryText(for: themeManager.isDarkMode))
                
                Spacer()
                
                if isSwipeMode {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .adaptiveFont(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text("Убрать")
                                .adaptiveFont(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        HStack(spacing: 4) {
                            Text("Лучшие")
                                .adaptiveFont(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Image(systemName: "arrow.right")
                                .adaptiveFont(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .adaptivePadding()
            .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 0.8)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.standardCornerRadius)
                    .fill(isSwipeMode ? 
                        AnyShapeStyle(LinearGradient(colors: [AppColors.accent(for: themeManager.isDarkMode), AppColors.accent(for: themeManager.isDarkMode).opacity(0.8)], startPoint: .leading, endPoint: .trailing)) :
                        AnyShapeStyle(AppColors.cardBackground(for: themeManager.isDarkMode))
                    )
                    .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Best of Best Section
    private var bestOfBestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .adaptiveFont(.title)
                    
                    Text("Лучшие из лучших")
                        .adaptiveFont(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                }
                
                Spacer()
                
                Text("\(superStarPhotos.count)")
                    .adaptiveFont(.caption)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    .padding(.horizontal, DeviceInfo.shared.spacing(0.6))
                    .padding(.vertical, DeviceInfo.shared.spacing(0.3))
                    .background(
                        Capsule()
                            .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                    )
            }
            .adaptivePadding()
            
            if isSwipeMode {
                SwipeablePhotoGrid(
                    photos: superStarPhotos,
                    photoManager: photoManager
                ) { photo in
                    withAnimation(AppAnimations.modal) {
                        selectedPhoto = photo
                        showingFullScreen = true
                    }
                }
                .adaptivePadding()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DeviceInfo.shared.screenSize.gridSpacing), count: DeviceInfo.shared.screenSize.gridColumns), spacing: DeviceInfo.shared.screenSize.gridSpacing) {
                    ForEach(superStarPhotos) { photo in
                        SuperStarPhotoCard(photo: photo, onTap: {
                            withAnimation(AppAnimations.modal) {
                                selectedPhoto = photo
                                showingFullScreen = true
                            }
                        })
                    }
                }
                .adaptivePadding()
            }
        }
    }
    
    // MARK: - Top Favorites Section
    private var topFavoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Недавние избранные")
                    .adaptiveFont(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                Spacer()
            }
            .adaptivePadding()
            
            if topFavouritePhotos.isEmpty {
                VStack(spacing: 16) {
                    Text("Пока нет избранных фото")
                        .adaptiveFont(.body)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 1.5)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DeviceInfo.shared.screenSize.gridSpacing) {
                        ForEach(topFavouritePhotos) { photo in
                            VStack(spacing: DeviceInfo.shared.spacing(0.5)) {
                                PhotoImageView(
                                    photo: photo,
                                    targetSize: Constants.PhotoProcessing.smallThumbnailSize
                                )
                                .adaptiveCornerRadius()
                                .onTapGesture {
                                    print("🖼️ FavoritesView: Top favorite photo tapped for fullscreen: \(photo.asset.localIdentifier)")
                                    withAnimation(AppAnimations.modal) {
                                        selectedPhoto = photo
                                        showingFullScreen = true
                                    }
                                }
                                
                                Button(action: {
                                    photoManager.setFavorite(photo, isFavorite: false)
                                }) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                                        .adaptiveFont(.caption)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .adaptivePadding()
                }
            }
        }
    }
    
    // MARK: - Monthly Photos Section
    private var monthlyPhotosSection: some View {
        Group {
            if favouritesByMonth.isEmpty {
                VStack(spacing: DeviceInfo.shared.spacing()) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title * 2))
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    
                    Text("Нет избранных фотографий")
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text("Удаленные фото будут появляться здесь")
                        .adaptiveFont(.body)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 2)
            } else {
                VStack(spacing: DeviceInfo.shared.spacing()) {
                    ForEach(favouritesByMonth, id: \.month) { monthSection in
                        MonthlyPhotoSection(
                            month: monthSection.month,
                            photos: monthSection.photos,
                            photoManager: photoManager,
                            isSwipeMode: isSwipeMode,
                            isExpanded: expandedMonths.contains(monthSection.month),
                            onToggle: {
                                if expandedMonths.contains(monthSection.month) {
                                    expandedMonths.remove(monthSection.month)
                                } else {
                                    expandedMonths.insert(monthSection.month)
                                }
                            },
                            onPhotoTap: { photo in
                                print("🖼️ FavoritesView: Monthly photo tapped for fullscreen: \(photo.asset.localIdentifier)")
                                withAnimation(AppAnimations.modal) {
                                    selectedPhoto = photo
                                    showingFullScreen = true
                                }
                            }
                        )
                    }
                }
                .adaptivePadding()
            }
        }
    }
    
    private func refreshData() {
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRefreshing = false
        }
    }
    
    /// Returns the correct icon for the theme switch button: sun for light, moon for dark, moon for system (default)
    private var themeIcon: String {
        switch themeManager.currentTheme {
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        case .system:
            return "moon" // default icon for system
        }
    }
    
    /// Toggles between light and dark themes. If system, switch to dark. If dark, switch to light. If light, switch to dark.
    private func toggleTheme() {
        switch themeManager.currentTheme {
        case .system:
            themeManager.setTheme(.dark)
        case .dark:
            themeManager.setTheme(.light)
        case .light:
            themeManager.setTheme(.dark)
        }
    }
}

struct MonthlyPhotoSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    let month: String
    let photos: [Photo]
    let photoManager: PhotoManager
    let isSwipeMode: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onPhotoTap: (Photo) -> Void
    
    // Photos are already sorted by date from the parent
    private var sortedPhotos: [Photo] {
        photos
    }
    
    // Dummy selection state for non-selectable grid
    @State private var dummySelected: Set<Photo> = []
    @State private var dummyIsSelecting: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Month Header
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(month)
                            .adaptiveFont(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        
                        Text("\(photos.count) фото")
                            .adaptiveFont(.body)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .adaptiveFont(.body)
                }
                .adaptivePadding()
                .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 0.6)
                .background(
                    RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                        .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Photos Grid (Expandable)
            if isExpanded {
                if isSwipeMode {
                    SwipeablePhotoGrid(
                        photos: sortedPhotos,
                        photoManager: photoManager
                    ) { photo in
                        onPhotoTap(photo)
                    }
                    .adaptivePadding(0.6) // Adjust padding for grid
                } else {
                    SelectablePhotoGrid(
                        photos: sortedPhotos,
                        selected: $dummySelected,
                        isSelecting: $dummyIsSelecting,
                        onTapSingle: { photo in onPhotoTap(photo) }
                    )
                    .constrainedToDevice(usePadding: false)
                    .frame(maxWidth: DeviceInfo.shared.isIPad ? 700 : .infinity)
                }
            }
        }
    }
}

struct FavouritePhotoCard: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    let photo: Photo
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Photo
            PhotoImageView(
                photo: photo,
                targetSize: CGSize(width: DeviceInfo.shared.screenSize.horizontalPadding * 5, 
                                 height: DeviceInfo.shared.screenSize.horizontalPadding * 5)
            )
            .adaptiveCornerRadius()
            .onTapGesture {
                onTap()
            }
            
            Button(action: {
                // Remove from favourites
                photoManager.setFavorite(photo, isFavorite: false)
            }) {
                Image(systemName: "heart.fill")
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    .adaptiveFont(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct SuperStarPhotoCard: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    let photo: Photo
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Photo with super star badge
            ZStack(alignment: .topTrailing) {
                PhotoImageView(
                    photo: photo,
                    targetSize: CGSize(width: DeviceInfo.shared.screenSize.horizontalPadding * 5, 
                                     height: DeviceInfo.shared.screenSize.horizontalPadding * 5)
                )
                .adaptiveCornerRadius()
                .onTapGesture {
                    onTap()
                }
                
                // Super star badge
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
                    .padding(4)
                    .background(
                        Circle()
                            .fill(.black.opacity(0.6))
                    )
                    .padding(4)
            }
            
            // Remove super star button
            Button(action: {
                photoManager.setSuperStar(photo, isSuperStar: false)
            }) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption2)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    FavoritesView()
}
