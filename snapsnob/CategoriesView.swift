import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var aiAnalysisManager: AIAnalysisManager
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isRefreshing = false
    @State private var selectedCategory: PhotoCategory?
    @State private var showingAIAnalysis = false
    @State private var dataVersion = 0
    @State private var selectedAlbum: PhotoAlbum?
    
    // AI-generated categories after analysis
    private var categories: [Category] {
        // Filter out trashed photos to ensure counts are accurate
        let categorizedPhotos = photoManager.categorizedPhotos.mapValues { photos in
            photos.filter { !$0.isTrashed }
        }
        return PhotoCategory.allCases.compactMap { photoCategory in
            guard let photos = categorizedPhotos[photoCategory], !photos.isEmpty else { return nil }
            return Category(
                name: photoCategory.rawValue,
                count: photos.count,
                icon: photoCategory.icon,
                color: .gray,
                thumbnail: "",
                photoCategory: photoCategory,
                thumbnailPhoto: photos.first
            )
        }.sorted { $0.count > $1.count }
    }
    
    // Albums from gallery before analysis
    private var albums: [PhotoAlbum] {
        photoManager.albums.filter { !$0.photos.isEmpty }
    }
    
    // Check if analysis has been completed in this session
    private var hasCompletedAnalysis: Bool {
        aiAnalysisManager.analysisPerformedThisSession
    }
    
    private var shouldShowAlbums: Bool {
        !hasCompletedAnalysis && aiAnalysisManager.getPhotosByCategory().isEmpty
    }
    
    private var totalPhotosCount: Int {
        photoManager.allPhotos.count
    }
    
    private var categorizedPhotosCount: Int {
        // Exclude trashed photos from the overall categorized count as well
        photoManager.categorizedPhotos.values.flatMap { $0 }.filter { !$0.isTrashed }.count
    }
    
    private var averageConfidence: String {
        let analyzedPhotos = photoManager.categorizedPhotos.values.flatMap { $0 }
        guard !analyzedPhotos.isEmpty else { return "0%" }
        
        let totalConfidence = analyzedPhotos.reduce(0.0) { $0 + $1.categoryConfidence }
        let average = totalConfidence / Float(analyzedPhotos.count)
        return "\(Int(average * 100))%"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DeviceInfo.shared.spacing(1.2)) {
                    // Statistics Section
                    VStack(spacing: DeviceInfo.shared.spacing(0.6)) {
                        HStack(spacing: DeviceInfo.shared.spacing(0.6)) {
                            StatCard(title: "Всего фото", value: "\(totalPhotosCount)", color: AppColors.accent(for: themeManager.isDarkMode))
                            StatCard(title: "Категоризировано", value: "\(categorizedPhotosCount)", color: AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                        
                        StatCard(title: "Средняя уверенность Vision", value: averageConfidence, color: AppColors.accent(for: themeManager.isDarkMode))
                    }
                    .adaptivePadding(1.2)
                    
                    // AI Analysis Button - Only show if analysis hasn't been completed
                    if aiAnalysisManager.canStartAnalysis {
                        Button(action: {
                            print("👁️ Apple Vision Analysis button tapped")
                            showingAIAnalysis = true
                        }) {
                            HStack(spacing: DeviceInfo.shared.spacing(0.8)) {
                                // Leading icon
                                Image(systemName: "brain.head.profile")
                                    .adaptiveFont(.title)
                                    .foregroundColor(.white)

                                // Title & subtitle – exactly one row each
                                VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.2)) {
                                    Text("Анализировать фотографии с Apple Vision")
                                        .adaptiveFont(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("Максимальная точность и качество")
                                        .adaptiveFont(.caption)
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                }
                                .layoutPriority(1)

                                Spacer()

                                // Chevron
                                Image(systemName: "chevron.right")
                                    .adaptiveFont(.body)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .adaptivePadding(1.0)
                            .padding(.vertical, DeviceInfo.shared.spacing(0.4))
                            .background(
                                LinearGradient(
                                    colors: [.black, .gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .adaptiveCornerRadius()
                            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .adaptivePadding(1.2)
                    }
                    
                    // Show completed analysis info if analysis is done
                    if hasCompletedAnalysis && !aiAnalysisManager.isAnalyzing {
                        VStack(spacing: DeviceInfo.shared.spacing(0.4)) {
                            HStack(spacing: DeviceInfo.shared.spacing(0.6)) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .adaptiveFont(.title)
                                
                                VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.2)) {
                                    Text("Анализ завершен")
                                        .adaptiveFont(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                    
                                    Text("Фотографии категоризированы с помощью Apple Vision")
                                        .adaptiveFont(.caption)
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                }
                                
                                Spacer()
                            }
                        }
                        .adaptivePadding(1.0)
                        .padding(.vertical, DeviceInfo.shared.spacing(0.6))
                        .background(
                            RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .adaptivePadding(1.2)
                    }
                    
                    // Categories Section
                    VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.8)) {
                        HStack {
                            Text(shouldShowAlbums ? "Альбомы" : "Категории")
                                .adaptiveFont(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                            Spacer()
                            
                            // Show count of items
                            if shouldShowAlbums {
                                Text("\(albums.count)")
                                    .adaptiveFont(.caption)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    .padding(.horizontal, DeviceInfo.shared.spacing(0.6))
                                    .padding(.vertical, DeviceInfo.shared.spacing(0.3))
                                    .background(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                                    .clipShape(Capsule())
                            } else {
                                Text("\(categories.count)")
                                    .adaptiveFont(.caption)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    .padding(.horizontal, DeviceInfo.shared.spacing(0.6))
                                    .padding(.vertical, DeviceInfo.shared.spacing(0.3))
                                    .background(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                                    .clipShape(Capsule())
                            }
                        }
                        .adaptivePadding(1.2)
                        
                        // Unified grid configuration. When displaying **albums** we cap the
                        // number of columns to the *album count* (so one album → one column,
                        // two albums → two columns, etc.) while preserving the standard card
                        // width used for categories. This prevents a single-album grid from
                        // stretching to full-screen width on iPhones.
                        let gridColumns: [GridItem] = {
                            // Determine the desired column count.
                            let deviceColumnCount = DeviceInfo.shared.screenSize.gridColumns
                            if shouldShowAlbums {
                                let columns = max(1, min(albums.count, deviceColumnCount))
                                return Array(
                                    repeating: GridItem(
                                        .flexible(),
                                        spacing: DeviceInfo.shared.screenSize.gridSpacing
                                    ),
                                    count: columns
                                )
                            } else {
                                return Array(
                                    repeating: GridItem(
                                        .flexible(),
                                        spacing: DeviceInfo.shared.screenSize.gridSpacing
                                    ),
                                    count: deviceColumnCount
                                )
                            }
                        }()

                        LazyVGrid(columns: gridColumns, spacing: DeviceInfo.shared.screenSize.gridSpacing) {
                            if shouldShowAlbums {
                                ForEach(albums) { album in
                                    AlbumCard(album: album) {
                                        withAnimation(AppAnimations.modal) {
                                            selectedAlbum = album
                                        }
                                    }
                                }
                            } else {
                                ForEach(categories) { category in
                                    RoundedCategoryCard(category: category, photoManager: photoManager) {
                                        withAnimation(AppAnimations.modal) {
                                            selectedCategory = category.photoCategory
                                        }
                                    }
                                }
                            }
                        }
                        .adaptivePadding(1.2)
                        
                        // Empty state for albums
                        if shouldShowAlbums && albums.isEmpty {
                            VStack(spacing: DeviceInfo.shared.spacing(1.0)) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title * 2.5))
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                
                                Text("Альбомы не найдены")
                                    .adaptiveFont(.title)
                                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                
                                Text("Начните анализ для автоматической категоризации фотографий")
                                    .adaptiveFont(.body)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, DeviceInfo.shared.spacing(2.0))
                            .adaptivePadding(1.2)
                        }
                        
                        // Empty state for categories
                        if !shouldShowAlbums && categories.isEmpty && hasCompletedAnalysis {
                            VStack(spacing: DeviceInfo.shared.spacing(1.0)) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title * 2.5))
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                
                                Text("Категории не найдены")
                                    .adaptiveFont(.title)
                                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                
                                Text("Попробуйте повторить анализ или проверьте настройки")
                                    .adaptiveFont(.body)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, DeviceInfo.shared.spacing(2.0))
                            .adaptivePadding(1.2)
                        }
                    }
                }
                .padding(.top, DeviceInfo.shared.spacing(0.4))
                .padding(.bottom, DeviceInfo.shared.spacing(1.6))
            }
            // Keep the familiar iPhone width on larger screens.
            .constrainedToDevice(usePadding: false)
            .navigationViewStyle(.stack)
            .navigationTitle("Категории")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        print("🔄 Refresh button tapped")
                        refreshCategories()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatCount(isRefreshing ? 10 : 0), value: isRefreshing)
                    }
                }
            }
            .sheet(item: $selectedCategory) { category in
                NavigationStack {
                    CategoryDetailView(category: category, aiAnalysisManager: aiAnalysisManager)
                        .environmentObject(photoManager)
                        .environmentObject(fullScreenPhotoManager)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
            }
            .sheet(item: $selectedAlbum) { album in
                NavigationStack {
                    AlbumDetailView(album: album)
                        .environmentObject(photoManager)
                        .environmentObject(fullScreenPhotoManager)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showingAIAnalysis) {
                AIAnalysisView {
                    showingAIAnalysis = false
                }
            }
            .onReceive(photoManager.$categorizedPhotos) { _ in
                dataVersion += 1
            }
            .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
        }
        .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
        .navigationViewStyle(.stack)
    }
    
    private func refreshCategories() {
        print("🔄 Starting manual refresh of categories…")
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRefreshing = false
            print("✅ Manual refresh finished")
        }
    }
}

struct Category: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let icon: String
    let color: Color
    let thumbnail: String
    let photoCategory: PhotoCategory
    let thumbnailPhoto: Photo?
}

struct StatCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DeviceInfo.shared.spacing(0.4)) {
            Text(value)
                .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title * 1.4))
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .adaptiveFont(.caption)
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DeviceInfo.shared.spacing(0.8))
        .padding(.horizontal, DeviceInfo.shared.spacing(0.6))
        .background(
            RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 8, x: 0, y: 2)
        )
    }
}

struct RoundedCategoryCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let category: Category
    let photoManager: PhotoManager
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Cover Image with rounded top corners
                Group {
                    if let thumbnailPhoto = category.thumbnailPhoto {
                        PhotoImageView(
                            photo: thumbnailPhoto,
                            targetSize: Constants.PhotoProcessing.smallThumbnailSize
                        )
                            .aspectRatio(1.6, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.secondaryBackground(for: themeManager.isDarkMode), AppColors.secondaryBackground(for: themeManager.isDarkMode).opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: category.icon)
                                    .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title * 1.8))
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                             )
                            .aspectRatio(1.6, contentMode: .fill)
                    }
                }
                .clipShape(
                    .rect(
                        topLeadingRadius: DeviceInfo.shared.screenSize.cornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: DeviceInfo.shared.screenSize.cornerRadius
                    )
                )
                
                // Content Section with rounded bottom corners
                VStack(spacing: DeviceInfo.shared.spacing(0.3)) {
                    HStack(spacing: DeviceInfo.shared.spacing(0.6)) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                                .frame(width: DeviceInfo.shared.spacing(1.8), 
                                     height: DeviceInfo.shared.spacing(1.8))
                            
                            Image(systemName: category.icon)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption * 1.4, weight: .semibold))
                        }
                        
                        // Title and Count
                        VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.1)) {
                            Text(category.name)
                                .adaptiveFont(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                .lineLimit(1)
                            
                            Text("\(category.count) фото")
                                .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption * 0.9))
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                        
                        Spacer()
                        
                        // Arrow Indicator
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption * 0.9, weight: .medium))
                    }
                }
                .padding(DeviceInfo.shared.spacing(0.8))
                .background(
                    RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                        .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                        .clipShape(
                            .rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: DeviceInfo.shared.screenSize.cornerRadius,
                                bottomTrailingRadius: DeviceInfo.shared.screenSize.cornerRadius,
                                topTrailingRadius: 0
                            )
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                .shadow(
                    color: AppColors.shadow(for: themeManager.isDarkMode),
                    radius: isPressed ? 4 : 8,
                    x: 0,
                    y: isPressed ? 2 : 4
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Handle press completion
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

#Preview {
    CategoriesView()
}
