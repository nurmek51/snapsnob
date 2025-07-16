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
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var isRefreshing = false
    @State private var selectedPhoto: Photo?
    @State private var showingFullScreen = false
    @State private var expandedGroup: String? = nil // Changed to allow only one group open at a time
    @State private var showingThemeSelector = false
    @State private var isSwipeMode = false
    
    // MARK: - Multi-Selection State
    @State private var selectedPhotos: Set<Photo> = []
    @State private var isSelectingMode = false
    
    // MARK: - Grouped Favorites Data
    
    // Recent favourite photos (last 14 days)
    private var recentFavoritePhotos: [Photo] {
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let favorites = photoManager.displayPhotos.filter { 
            $0.isFavorite && $0.creationDate >= fourteenDaysAgo
        }
        return favorites.sorted { $0.creationDate > $1.creationDate }
    }
    
    // Top favorite photos for preview (up to 6 most recent)
    private var topFavouritePhotos: [Photo] {
        Array(recentFavoritePhotos.prefix(6))
    }
    
    // Super star photos (Best of the Best)
    private var superStarPhotos: [Photo] {
        let superStars = photoManager.displayPhotos.filter { $0.isSuperStar }
        return superStars.sorted { $0.creationDate > $1.creationDate }
    }
    
    // Favourite photos grouped by month (excluding recent ones from last 14 days)
    private var favouritesByMonth: [(month: String, photos: [Photo])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale.current // Use current system locale instead of hardcoded Russian

        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        
        // 1. Filter favourites (excluding recent ones already shown in "Recent Favorites")
        let favourites = photoManager.displayPhotos.filter { 
            $0.isFavorite && $0.creationDate < fourteenDaysAgo
        }

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
    
    // MARK: - Header Section (static)
    private var headerSection: some View {
        HStack(alignment: .center, spacing: DeviceInfo.shared.spacing(0.8)) {
            Image(systemName: themeManager.isDarkMode ? "heart.fill" : "heart")
                .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title, weight: .semibold))
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                .frame(width: DeviceInfo.shared.spacing(2.2), height: DeviceInfo.shared.spacing(2.2))
            
            Text("navigation.favorites".localized)
                .adaptiveFont(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
            
            Spacer()
            
            // Theme switcher button
            Button(action: { toggleTheme() }) {
                Image(systemName: themeIcon)
                    .font(.system(size: DeviceInfo.shared.screenSize.fontSize.body, weight: .medium))
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    .frame(width: DeviceInfo.shared.spacing(2.0), height: DeviceInfo.shared.spacing(2.0))
                    .background(
                        Circle()
                            .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("\(photoManager.favoritePhotosCount)")
                .adaptiveFont(.caption)
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                .padding(.horizontal, DeviceInfo.shared.spacing(0.8))
                .padding(.vertical, DeviceInfo.shared.spacing(0.4))
                .background(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: DeviceInfo.shared.spacing(4.5), alignment: .center)
        .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
        .padding(.horizontal, DeviceInfo.shared.spacing(1.2))
        .padding(.vertical, DeviceInfo.shared.spacing(0.8))
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.standardCornerRadius)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                .shadow(color: AppColors.shadow(for: themeManager.isDarkMode).opacity(0.5), radius: 4, x: 0, y: -1) // Top shadow (reduced)
                .shadow(color: AppColors.shadow(for: themeManager.isDarkMode).opacity(0.5), radius: 4, x: 0, y: 1) // Bottom shadow (reduced)
        )
        .adaptivePadding(1.2)
    }
    
    // MARK: - Stats Section (separate from header)
    private var statsSection: some View {
        VStack(spacing: DeviceInfo.shared.spacing(0.6)) {
            HStack(spacing: DeviceInfo.shared.spacing(0.6)) {
                StatCard(title: "favorites.totalPhotos".localized, value: "\(photoManager.totalPhotosCount)", color: AppColors.accent(for: themeManager.isDarkMode))
                StatCard(title: "favorites.favoritesCount".localized, value: "\(photoManager.favoritePhotosCount)", color: AppColors.secondaryText(for: themeManager.isDarkMode))
            }
            
            HStack(spacing: DeviceInfo.shared.spacing(0.6)) {
                StatCard(title: "favorites.thisWeek".localized, value: "+\(photoManager.photosLastWeek)", color: AppColors.accent(for: themeManager.isDarkMode))
                StatCard(title: "favorites.bestPhotos".localized, value: "\(photoManager.superStarPhotosCount)", color: .yellow)
            }
        }
        .adaptivePadding(1.2)
    }
    
    var body: some View {
        Group {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DeviceInfo.shared.spacing(1.2)) {
                        headerSection // <- moved inside ScrollView
                        statsSection // <- separated stats section
                        swipeModeSection // <- renamed for clarity
                        // New Grouped Navigation Structure
                        groupedFavoritesSection
                    }
                    .padding(.top, {
                        let multiplier: CGFloat
                        switch DeviceInfo.shared.screenSize {
                        case .max:   multiplier = 0.2
                        case .plus:  multiplier = 0.3
                        default:     multiplier = 0.4
                        }
                        return DeviceInfo.SafeAreaHelper.headerTopPadding * multiplier
                    }())
                    .padding(.bottom, DeviceInfo.shared.spacing(1.6))
                }
            }
            .constrainedToDevice(usePadding: false)
            .navigationTitle("navigation.favorites".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { refreshData() }) {
                        Image(systemName: themeManager.isDarkMode ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                            .font(.system(size: DeviceInfo.shared.screenSize.fontSize.body, weight: .medium))
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
                let (photoGroup, groupTitle) = getPhotoGroupForFullScreen(photo: photo)
                FullScreenPhotoView(
                    photo: photo,
                    photoManager: photoManager,
                    photoGroup: photoGroup,
                    groupTitle: groupTitle
                ) {
                    withAnimation(AppAnimations.modal) {
                        showingFullScreen = false
                        selectedPhoto = nil
                    }
                }
                .presentationBackground(.clear)
            }
            .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
        }
        // Removed duplicate navigationTitle / background modifiers to avoid side-effects.
        .overlay(
            // Selection Toolbar
            selectionToolbar,
            alignment: .bottom
        )
    }
    
    // MARK: - Swipe Mode Section
    private var swipeModeSection: some View {
        swipeModeToggle
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
                
                Text(isSwipeMode ? "favorites.normalMode".localized : "favorites.swipeMode".localized)
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
                            Text("favorites.swipeLeft".localized)
                                .adaptiveFont(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        HStack(spacing: 4) {
                            Text("favorites.swipeRight".localized)
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
    
    // MARK: - Recent Favorites Conveyor
    // private var recentFavoritesConveyor: some View {
    //     // Show only if there are recent favorites
    //     Group {
    //         if !recentFavoritePhotos.isEmpty {
    //             VStack(alignment: .leading, spacing: 12) {
    //                 HStack(spacing: 8) {
    //                     Image(systemName: "clock.arrow.circlepath")
    //                         .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
    //                         .adaptiveFont(.title)
    //                     Text("Недавние избранные")
    //                         .adaptiveFont(.body)
    //                         .fontWeight(.semibold)
    //                         .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
    //                     Spacer()
    //                 }
    //                 .adaptivePadding()
    //                 .padding(.horizontal)
                    
    //                 // Horizontal conveyor
    //                 ScrollView(.horizontal, showsIndicators: false) {
    //                     HStack(spacing: DeviceInfo.shared.spacing(0.8)) {
    //                         let thumbSide: CGFloat = {
    //                             switch DeviceInfo.shared.screenSize {
    //                             case .compact: return 90
    //                             case .standard: return 100
    //                             case .plus, .max: return 110
    //                             case .iPad: return 140
    //                             case .iPadPro: return 160
    //                             }
    //                         }()
    //                         ForEach(recentFavoritePhotos) { photo in
    //                             OptimizedPhotoView(
    //                                 photo: photo,
    //                                 targetSize: CGSize(width: thumbSide, height: thumbSide)
    //                             )
    //                             .frame(width: thumbSide, height: thumbSide)
    //                             .clipped()
    //                             .adaptiveCornerRadius()
    //                             .onTapGesture {
    //                                 print("🖼️ Conveyor tap: \(photo.asset.localIdentifier)")
    //                                 withAnimation(AppAnimations.modal) {
    //                                     selectedPhoto = photo
    //                                     showingFullScreen = true
    //                                 }
    //                             }
    //                         }
    //                     }
    //                     .adaptivePadding()
    //                     .padding(.horizontal)
    //                 }
    //             }
    //             .adaptivePadding()
    //             .padding(.vertical)
    //         }
    //     }
    // }
    
    // MARK: - Best of Best Section
    private var bestOfBestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .adaptiveFont(.title)
                    
                    Text("favorites.bestOfBest".localized)
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
                SelectablePhotoGrid(
                    photos: superStarPhotos,
                    selected: $selectedPhotos,
                    isSelecting: $isSelectingMode,
                    onTapSingle: { photo in
                        withAnimation(AppAnimations.modal) {
                            selectedPhoto = photo
                            showingFullScreen = true
                        }
                    }
                )
                .constrainedToDevice(usePadding: false)
                .frame(maxWidth: DeviceInfo.shared.isIPad ? 700 : .infinity)
                .adaptivePadding()
            }
        }
    }
    
    // MARK: - Grouped Favorites Section
    private var groupedFavoritesSection: some View {
        VStack(spacing: DeviceInfo.shared.spacing()) {
            // Recent Favorites Group (if any)
            if !recentFavoritePhotos.isEmpty {
                FavoriteGroupSection(
                    title: "favorites.recentFavorites".localized,
                    subtitle: "favorites.recentSubtitle".localized,
                    count: recentFavoritePhotos.count,
                    icon: "clock.fill",
                    photos: recentFavoritePhotos,
                    photoManager: photoManager,
                    isSwipeMode: isSwipeMode,
                    isExpanded: expandedGroup == "recent",
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            expandedGroup = expandedGroup == "recent" ? nil : "recent"
                        }
                    },
                    onPhotoTap: { photo in
                        print("🖼️ FavoritesView: Recent photo tapped for fullscreen: \(photo.asset.localIdentifier)")
                        withAnimation(AppAnimations.modal) {
                            selectedPhoto = photo
                            showingFullScreen = true
                        }
                    },
                    selectedPhotos: $selectedPhotos,
                    isSelectingMode: $isSelectingMode
                )
            }
            
            // Monthly Groups
            ForEach(favouritesByMonth, id: \.month) { monthSection in
                FavoriteGroupSection(
                    title: monthSection.month,
                    subtitle: nil,
                    count: monthSection.photos.count,
                    icon: "calendar",
                    photos: monthSection.photos,
                    photoManager: photoManager,
                    isSwipeMode: isSwipeMode,
                    isExpanded: expandedGroup == monthSection.month,
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            expandedGroup = expandedGroup == monthSection.month ? nil : monthSection.month
                        }
                    },
                    onPhotoTap: { photo in
                        print("🖼️ FavoritesView: Monthly photo tapped for fullscreen: \(photo.asset.localIdentifier)")
                        withAnimation(AppAnimations.modal) {
                            selectedPhoto = photo
                            showingFullScreen = true
                        }
                    },
                    selectedPhotos: $selectedPhotos,
                    isSelectingMode: $isSelectingMode
                )
            }
            
            // Empty state if no favorites at all
            if recentFavoritePhotos.isEmpty && favouritesByMonth.isEmpty {
                VStack(spacing: DeviceInfo.shared.spacing()) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title * 2))
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    
                    Text("favorites.noFavoritesTitle".localized)
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text("favorites.noFavoritesMessage".localized)
                        .adaptiveFont(.body)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 2)
            }
        }
        .adaptivePadding()
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
            return themeManager.isDarkMode ? "sun.max.fill" : "sun.max"
        case .dark:
            return themeManager.isDarkMode ? "moon.fill" : "moon"
        case .system:
            return themeManager.isDarkMode ? "moon.fill" : "moon" // default icon for system
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

    /// Helper to determine which group a photo belongs to for FullScreenPhotoView
    private func getPhotoGroupForFullScreen(photo: Photo) -> ([Photo], String?) {
        // Check if photo is in recent favorites
        if recentFavoritePhotos.contains(where: { $0.id == photo.id }) {
            return (recentFavoritePhotos, "favorites.recentFavorites".localized)
        }
        
        // Check monthly groups
        for monthSection in favouritesByMonth {
            if monthSection.photos.contains(where: { $0.id == photo.id }) {
                return (monthSection.photos, monthSection.month)
            }
        }
        
        // Check super stars
        if superStarPhotos.contains(where: { $0.id == photo.id }) {
            return (superStarPhotos, "favorites.bestOfBest".localized)
        }
        
        // Fallback to single photo
        return ([photo], nil as String?)
    }

    // MARK: - Selection Toolbar
    private var selectionToolbar: some View {
        Group {
            if isSelectingMode && !selectedPhotos.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        // Done button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedPhotos.removeAll()
                                isSelectingMode = false
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .adaptiveFont(.body)
                                Text("action.done".localized)
                                    .adaptiveFont(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 0.6)
                        .background(
                            RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                        )
                        
                        // Add to Super Stars button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                for photo in selectedPhotos {
                                    photoManager.setSuperStar(photo, isSuperStar: true)
                                }
                                selectedPhotos.removeAll()
                                isSelectingMode = false
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("favorites.bestPhotos".localized)
                                    .adaptiveFont(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 0.6)
                        .background(
                            RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                        )
                        
                        // Remove from Favorites button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                for photo in selectedPhotos {
                                    photoManager.setFavorite(photo, isFavorite: false)
                                }
                                selectedPhotos.removeAll()
                                isSelectingMode = false
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.slash.fill")
                                    .foregroundColor(.red)
                                Text("favorites.removeFromFavorites".localized)
                                    .adaptiveFont(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 0.6)
                        .background(
                            RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                        )
                    }
                    .padding(.horizontal, DeviceInfo.shared.screenSize.horizontalPadding)
                    .padding(.bottom, DeviceInfo.shared.screenSize.horizontalPadding)
                    .background(
                        Rectangle()
                            .fill(AppColors.background(for: themeManager.isDarkMode))
                            .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 8, x: 0, y: -2)
                    )
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Favorite Group Section Component

struct FavoriteGroupSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    let title: String
    let subtitle: String?
    let count: Int
    let icon: String
    let photos: [Photo]
    let photoManager: PhotoManager
    let isSwipeMode: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onPhotoTap: (Photo) -> Void
    
    // Real selection state from parent
    @Binding var selectedPhotos: Set<Photo>
    @Binding var isSelectingMode: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Group Header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: icon)
                        .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                        .adaptiveFont(.title)
                        .frame(width: DeviceInfo.shared.spacing(3), alignment: .center)
                    
                    // Title and subtitle
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .adaptiveFont(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .adaptiveFont(.caption)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                    }
                    
                    Spacer()
                    
                    // Photo count badge
                    Text("\(count)")
                        .adaptiveFont(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .padding(.horizontal, DeviceInfo.shared.spacing(1.2))
                        .padding(.vertical, DeviceInfo.shared.spacing(0.6))
                        .background(
                            Capsule()
                                .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                        )
                    
                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .adaptiveFont(.body)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .adaptivePadding()
                .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 0.8)
                .background(
                    RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                        .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                        .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Photos Grid (Expandable)
            if isExpanded {
                if isSwipeMode {
                    SwipeablePhotoGrid(
                        photos: photos,
                        photoManager: photoManager
                    ) { photo in
                        onPhotoTap(photo)
                    }
                    .adaptivePadding(0.6) // Adjust padding for grid
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 1.05))
                    ))
                } else {
                    SelectablePhotoGrid(
                        photos: photos,
                        selected: $selectedPhotos,
                        isSelecting: $isSelectingMode,
                        onTapSingle: { photo in onPhotoTap(photo) }
                    )
                    .constrainedToDevice(usePadding: false)
                    .frame(maxWidth: DeviceInfo.shared.isIPad ? 700 : .infinity)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 1.05))
                    ))
                }
            }
        }
    }
}

struct MonthlyPhotoSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    let month: String
    let photos: [Photo]
    let photoManager: PhotoManager
    let isSwipeMode: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onPhotoTap: (Photo) -> Void
    
    // Real selection state from parent
    @Binding var selectedPhotos: Set<Photo>
    @Binding var isSelectingMode: Bool
    
    // Photos are already sorted by date from the parent
    private var sortedPhotos: [Photo] {
        photos
    }
    
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
                        
                        Text(String(format: "favorites.photosCount".localized, photos.count))
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
                        selected: $selectedPhotos,
                        isSelecting: $isSelectingMode,
                        onTapSingle: { photo in onPhotoTap(photo) }
                    )
                    .constrainedToDevice(usePadding: false)
                    .frame(maxWidth: DeviceInfo.shared.isIPad ? 700 : .infinity)
                }
            }
        }
    }
}

#Preview {
    FavoritesView()
}

