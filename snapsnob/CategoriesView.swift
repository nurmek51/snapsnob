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
                VStack(spacing: 24) {
                    // Statistics Section
                    VStack(spacing: 16) {
                        HStack {
                            StatCard(title: "Всего фото", value: "\(totalPhotosCount)", color: AppColors.accent(for: themeManager.isDarkMode))
                            StatCard(title: "Категоризировано", value: "\(categorizedPhotosCount)", color: AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                        
                        StatCard(title: "Средняя уверенность Vision", value: averageConfidence, color: AppColors.accent(for: themeManager.isDarkMode))
                    }
                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
                    
                    // AI Analysis Button - Only show if analysis hasn't been completed
                    if aiAnalysisManager.canStartAnalysis {
                        VStack(spacing: 16) {
                            Button(action: {
                                print("👁️ Apple Vision Analysis button tapped")
                                showingAIAnalysis = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "brain.head.profile")
                                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .title : .title2)
                                        .foregroundColor(.white)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Анализировать фотографии с Apple Vision")
                                            .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.leading)
                                        
                                        Text("Максимальная точность и качество")
                                            .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .title2 : .title3)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 30 : 20)
                                .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16)
                                .background(
                                    LinearGradient(
                                        colors: [.black, .gray],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16))
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
                    }
                    
                    // Show completed analysis info if analysis is done
                    if hasCompletedAnalysis && !aiAnalysisManager.isAnalyzing {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Анализ завершен")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                    
                                    Text("Фотографии категоризированы с помощью Apple Vision")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                }
                                
                                Spacer()
                                
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
                    }
                    
                    // Categories Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(shouldShowAlbums ? "Альбомы" : "Категории")
                                .font(UIDevice.current.userInterfaceIdiom == .pad ? .title : .title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                            Spacer()
                            
                            // Show count of items
                            if shouldShowAlbums {
                                Text("\(albums.count)")
                                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8)
                                    .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4)
                                    .background(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                                    .clipShape(Capsule())
                            } else {
                                Text("\(categories.count)")
                                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8)
                                    .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4)
                                    .background(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
                        
                        // Grid with improved layout
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16),
                            GridItem(.flexible(), spacing: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16)
                        ], spacing: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16) {
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
                        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
                        
                        // Empty state for albums
                        if shouldShowAlbums && albums.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 50 : 40))
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                
                                Text("Альбомы не найдены")
                                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title2 : .headline)
                                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                
                                Text("Начните анализ для автоматической категоризации фотографий")
                                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .body)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 60 : 40)
                            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
                        }
                        
                        // Empty state for categories
                        if !shouldShowAlbums && categories.isEmpty && hasCompletedAnalysis {
                            VStack(spacing: 16) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 50 : 40))
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                
                                Text("Категории не найдены")
                                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title2 : .headline)
                                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                
                                Text("Попробуйте повторить анализ или проверьте настройки")
                                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .body)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 60 : 40)
                            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
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
        VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8) {
            Text(value)
                .font(UIDevice.current.userInterfaceIdiom == .pad ? .largeTitle : .title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16)
        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12)
        .background(
            RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16)
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
                            targetSize: CGSize(width: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 180, 
                                             height: UIDevice.current.userInterfaceIdiom == .pad ? 170 : 100)
                        )
                        .aspectRatio(1.8, contentMode: .fill)
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
                                    .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 40 : 28))
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                             )
                            .aspectRatio(1.8, contentMode: .fill)
                    }
                }
                .clipShape(
                    .rect(
                        topLeadingRadius: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
                    )
                )
                
                // Content Section with rounded bottom corners
                VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4) {
                    HStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                                .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 40 : 28, 
                                     height: UIDevice.current.userInterfaceIdiom == .pad ? 40 : 28)
                            
                            Image(systemName: category.icon)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 12, weight: .semibold))
                        }
                        
                        // Title and Count
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                .lineLimit(1)
                            
                            Text("\(category.count) фото")
                                .font(UIDevice.current.userInterfaceIdiom == .pad ? .callout : .caption2)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                        
                        Spacer()
                        
                        // Arrow Indicator
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 14 : 10, weight: .medium))
                    }
                }
                .padding(UIDevice.current.userInterfaceIdiom == .pad ? 14 : 10)
                .background(
                    RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16)
                        .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                        .clipShape(
                            .rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16,
                                bottomTrailingRadius: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16,
                                topTrailingRadius: 0
                            )
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16)
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
