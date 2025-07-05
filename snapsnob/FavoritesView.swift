import SwiftUI
import Photos

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
                        showingThemeSelector = true
                    }) {
                        Image(systemName: themeManager.currentTheme.icon)
                            .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        refreshRatings()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatCount(isRefreshing ? 10 : 0), value: isRefreshing)
                    }
                }
            }
            .sheet(isPresented: $showingThemeSelector) {
                ThemeSelectorView()
                    .environmentObject(themeManager)
            }
            .overlay {
                if showingFullScreen, let photo = selectedPhoto {
                    FullScreenPhotoView(photo: photo, photoManager: photoManager) {
                        print("🖼️ FavoritesView: Dismissing fullscreen photo view")
                        withAnimation(AppAnimations.modal) {
                            showingFullScreen = false
                            selectedPhoto = nil
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .onChange(of: showingFullScreen) { oldValue, newValue in
                print("🔄 FavoritesView: showingFullScreen changed from \(oldValue) to \(newValue)")
                if newValue {
                    print("🔍 FavoritesView: selectedPhoto when showing fullscreen: \(selectedPhoto?.asset.localIdentifier ?? "nil")")
                }
            }
            .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
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
        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
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
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title2 : .title3)
                    .foregroundColor(isSwipeMode ? .white : AppColors.accent(for: themeManager.isDarkMode))
                
                Text(isSwipeMode ? "Обычный режим" : "Режим свайпа")
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .headline)
                    .fontWeight(.medium)
                    .foregroundColor(isSwipeMode ? .white : AppColors.primaryText(for: themeManager.isDarkMode))
                
                Spacer()
                
                if isSwipeMode {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text("Убрать")
                                .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        HStack(spacing: 4) {
                            Text("Лучшие")
                                .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Image(systemName: "arrow.right")
                                .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 30 : 20)
            .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16)
            .background(
                RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16)
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
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .title2 : .title3)
                    
                    Text("Лучшие из лучших")
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                }
                
                Spacer()
                
                Text("\(superStarPhotos.count)")
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8)
                    .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4)
                    .background(
                        Capsule()
                            .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                    )
            }
            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
            
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
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12) {
                    ForEach(superStarPhotos) { photo in
                        SuperStarPhotoCard(photo: photo, onTap: {
                            withAnimation(AppAnimations.modal) {
                                selectedPhoto = photo
                                showingFullScreen = true
                            }
                        })
                    }
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
            }
        }
    }
    
    // MARK: - Top Favorites Section
    private var topFavoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Недавние избранные")
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                Spacer()
            }
            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
            
            if topFavouritePhotos.isEmpty {
                VStack(spacing: 16) {
                    Text("Пока нет избранных фото")
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .body)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 30 : 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12) {
                        ForEach(topFavouritePhotos) { photo in
                            VStack(spacing: 8) {
                                PhotoImageView(
                                    photo: photo,
                                    targetSize: CGSize(width: UIDevice.current.userInterfaceIdiom == .pad ? 120 : 80, 
                                                     height: UIDevice.current.userInterfaceIdiom == .pad ? 120 : 80)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12))
                                .onTapGesture {
                                    print("🖼️ RatingsView: Top rated photo tapped for fullscreen: \(photo.asset.localIdentifier)")
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
                                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
                }
            }
        }
    }
    
    // MARK: - Monthly Photos Section
    private var monthlyPhotosSection: some View {
        Group {
            if favouritesByMonth.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 60 : 50))
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    
                    Text("Нет избранных фотографий")
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .title : .title2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text("Удаленные фото будут появляться здесь")
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .body)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 60 : 40)
            } else {
                VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16) {
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
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
            }
        }
    }
    
    private func refreshRatings() {
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRefreshing = false
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
    
    // Photos are already sorted by rating from the parent
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
                            .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        
                        Text("\(photos.count) фото")
                            .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 14, weight: .medium))
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16)
                .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12)
                .background(
                    RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12)
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
                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12) // Adjust padding for grid
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12) {
                        ForEach(sortedPhotos) { photo in
                            FavouritePhotoCard(photo: photo, onTap: {
                                onPhotoTap(photo)
                            })
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
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
                targetSize: CGSize(width: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 100, 
                                 height: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 100)
            )
            .clipShape(RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12))
            .onTapGesture {
                onTap()
            }
            
            Button(action: {
                // Remove from favourites
                photoManager.setFavorite(photo, isFavorite: false)
            }) {
                Image(systemName: "heart.fill")
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption2)
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
                    targetSize: CGSize(width: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 100, 
                                     height: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 100)
                )
                .clipShape(RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12))
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
