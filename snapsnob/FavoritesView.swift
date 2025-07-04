import SwiftUI
import Photos

struct RatingsView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var aiManager: AIAnalysisManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isRefreshing = false
    @State private var selectedPhoto: Photo?
    @State private var showingFullScreen = false
    @State private var expandedMonths: Set<String> = []
    @State private var showingThemeSelector = false
    
    // Recent favourite photos (up to 6 most recent)
    private var topFavouritePhotos: [Photo] {
        // Break the chained calls into discrete steps for faster type-checking.
        let favourites = photoManager.displayPhotos.filter { $0.isFavorite }
        let sorted = favourites.sorted { $0.creationDate > $1.creationDate }
        let limited = Array(sorted.prefix(6))
        return limited
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
                    // Dashboard Section (Always at top)
                    VStack(spacing: 16) {
                        HStack {
                            // Themed dashboard cards
                            StatCard(title: "Всего фото", value: "\(photoManager.totalPhotosCount)", color: AppColors.accent(for: themeManager.isDarkMode))
                            StatCard(title: "Избранные", value: "\(photoManager.favoritePhotosCount)", color: AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                        
                        HStack {
                            StatCard(title: "За неделю", value: "+\(photoManager.photosLastWeek)", color: AppColors.accent(for: themeManager.isDarkMode))
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Top 6 Photos Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Недавние избранные")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        if topFavouritePhotos.isEmpty {
                            VStack(spacing: 16) {
                                                            Text("Пока нет избранных фото")
                                .font(.body)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(topFavouritePhotos) { photo in
                                        VStack(spacing: 8) {
                                            PhotoImageView(
                                                photo: photo,
                                                targetSize: CGSize(width: 80, height: 80)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .onTapGesture {
                                                print("🖼️ RatingsView: Top rated photo tapped for fullscreen: \(photo.asset.localIdentifier)")
                                                withAnimation(AppAnimations.modal) {
                                                    selectedPhoto = photo
                                                    showingFullScreen = true
                                                }
                                                print("🔍 RatingsView: selectedPhoto set, showingFullScreen = \(showingFullScreen)")
                                            }
                                            
                                            Button(action: {
                                                // Remove from favourites
                                                photoManager.setFavorite(photo, isFavorite: false)
                                            }) {
                                                Image(systemName: "heart.fill")
                                                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                                                    .font(.caption2)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    // Monthly Photo Sections
                    if favouritesByMonth.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 50))
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            
                            Text("Нет избранных фотографий")
                                .font(.body)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(favouritesByMonth, id: \.month) { monthSection in
                                MonthlyPhotoSection(
                                    month: monthSection.month,
                                    photos: monthSection.photos,
                                    photoManager: photoManager,
                                    isExpanded: expandedMonths.contains(monthSection.month),
                                    onToggle: {
                                        if expandedMonths.contains(monthSection.month) {
                                            expandedMonths.remove(monthSection.month)
                                        } else {
                                            expandedMonths.insert(monthSection.month)
                                        }
                                    },
                                    onPhotoTap: { photo in
                                        print("🖼️ RatingsView: Monthly photo tapped for fullscreen: \(photo.asset.localIdentifier)")
                                        withAnimation(AppAnimations.modal) {
                                            selectedPhoto = photo
                                            showingFullScreen = true
                                        }
                                        print("🔍 RatingsView: selectedPhoto set, showingFullScreen = \(showingFullScreen)")
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            // Centre content and cap width on iPad.
            .constrainedToDevice(usePadding: false)
            .navigationTitle("Рейтинги")
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
                        print("🖼️ RatingsView: Dismissing fullscreen photo view")
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
                print("🔄 RatingsView: showingFullScreen changed from \(oldValue) to \(newValue)")
                if newValue {
                    print("🔍 RatingsView: selectedPhoto when showing fullscreen: \(selectedPhoto?.asset.localIdentifier ?? "nil")")
                }
            }
            .background(AppColors.background(for: themeManager.isDarkMode))
        }
        .background(AppColors.background(for: themeManager.isDarkMode))
        .navigationViewStyle(.stack)
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
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        
                        Text("\(photos.count) фото")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Photos Grid (Expandable)
            if isExpanded {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
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
                targetSize: CGSize(width: 100, height: 100)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                onTap()
            }
            
            Button(action: {
                // Remove from favourites
                photoManager.setFavorite(photo, isFavorite: false)
            }) {
                Image(systemName: "heart.fill")
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    .font(.caption2)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    RatingsView()
}
