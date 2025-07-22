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
                name: photoCategory.localizedName,
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
    
    // Remove hasCompletedAnalysis, shouldShowAlbums, and related logic
    // Instead, show albums if not currently analyzing and no categorized photos exist
    private var shouldShowAlbums: Bool {
        return !aiAnalysisManager.isAnalyzing && photoManager.categorizedPhotos.isEmpty
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
    
    // MARK: - Header Section (static)
    private var headerSection: some View {
        HStack(alignment: .center, spacing: DeviceInfo.shared.spacing(0.8)) {
            Image(systemName: shouldShowAlbums ? 
                  (themeManager.isDarkMode ? "rectangle.stack.fill" : "rectangle.stack") : 
                  (themeManager.isDarkMode ? "square.grid.2x2.fill" : "square.grid.2x2"))
                .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title, weight: .semibold))
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                .frame(width: DeviceInfo.shared.spacing(2.2), height: DeviceInfo.shared.spacing(2.2))
            
            Text(shouldShowAlbums ? "category.albums".localized : "navigation.categories".localized)
                .adaptiveFont(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
            
            Spacer()
            
            Text(shouldShowAlbums ? "\(albums.count)" : "\(categories.count)")
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
                StatCard(title: "common.totalPhotos".localized, value: "\(totalPhotosCount)", color: AppColors.accent(for: themeManager.isDarkMode))
                StatCard(title: "common.categorized".localized, value: "\(categorizedPhotosCount)", color: AppColors.secondaryText(for: themeManager.isDarkMode))
            }
            
            StatCard(title: "common.averageConfidence".localized, value: averageConfidence, color: AppColors.accent(for: themeManager.isDarkMode))
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
                        
                        // AI Analysis Button - Only show if not currently analyzing
                        if !aiAnalysisManager.isAnalyzing {
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
                                        Text("ai.analyzePhotos".localized)
                                            .adaptiveFont(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Text("ai.maximumAccuracy".localized)
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
                            // Ensure this button stays on top of any overlapping views
                            .zIndex(1)
                        }
                        
                        // Show completed analysis info if categorized photos exist and not analyzing
                        if !shouldShowAlbums && !aiAnalysisManager.isAnalyzing {
                            VStack(spacing: DeviceInfo.shared.spacing(0.4)) {
                                HStack(spacing: DeviceInfo.shared.spacing(0.6)) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .adaptiveFont(.title)
                                    
                                    VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.2)) {
                                        Text("common.analysisComplete".localized)
                                            .adaptiveFont(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                        
                                        Text("common.photosCategorizationComplete".localized)
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
                                Text(shouldShowAlbums ? "category.albums".localized : "navigation.categories".localized)
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
                                // Determine the desired column count with separate logic for albums so they remain readable.
                                let device = DeviceInfo.shared.screenSize
                                if shouldShowAlbums {
                                    // Wider album cards: fewer columns on phones, more on tablets.
                                    let albumColumnLimit: Int
                                    switch device {
                                    case .compact, .standard:
                                        albumColumnLimit = 2
                                    // Keep Plus/Max phones at 2 columns to match Standard layout
                                    case .plus, .max:
                                        albumColumnLimit = 2
                                    case .iPad:
                                        albumColumnLimit = 4
                                    case .iPadPro:
                                        albumColumnLimit = 5
                                    }
                                    let columns = max(1, min(albums.count, albumColumnLimit))
                                    return Array(
                                        repeating: GridItem(
                                            .flexible(),
                                            spacing: DeviceInfo.shared.screenSize.gridSpacing
                                        ),
                                        count: columns
                                    )
                                } else {
                                    // Tighter column limits so cards remain readable on wider phones/tablets
                                    let categoryColumnLimit: Int
                                    switch device {
                                    case .compact, .standard:
                                        categoryColumnLimit = 2
                                    // Use two columns on Plus/Max for the same look as Standard
                                    case .plus, .max:
                                        categoryColumnLimit = 2
                                    case .iPad:
                                        categoryColumnLimit = 4
                                    case .iPadPro:
                                        categoryColumnLimit = 5
                                    }
                                    let columns = max(1, min(categories.count, categoryColumnLimit))
                                    return Array(
                                        repeating: GridItem(
                                            .flexible(),
                                            spacing: DeviceInfo.shared.screenSize.gridSpacing
                                        ),
                                        count: columns
                                    )
                                }
                            }()

                            LazyVGrid(columns: gridColumns, spacing: DeviceInfo.shared.screenSize.gridSpacing) {
                                if shouldShowAlbums {
                                    ForEach(albums) { album in
                                        AlbumCard(album: album) {
                                            print("📂 Album selected from grid: \(album.title)")
                                            withAnimation(AppAnimations.modal) {
                                                selectedAlbum = album
                                            }
                                        }
                                        .id(album.id) // Ensure proper identity for SwiftUI
                                    }
                                } else {
                                    ForEach(categories) { category in
                                        RoundedCategoryCard(category: category, photoManager: photoManager) {
                                            print("📊 Category selected from grid: \(category.name)")
                                            withAnimation(AppAnimations.modal) {
                                                selectedCategory = category.photoCategory
                                            }
                                        }
                                        .id(category.id) // Ensure proper identity for SwiftUI
                                    }
                                }
                            }
                            .padding(.horizontal, DeviceInfo.shared.screenSize.horizontalPadding) // Add horizontal padding to prevent edge issues
                            .padding(.vertical, DeviceInfo.shared.spacing(0.5)) // Small vertical padding
                            
                            // Empty state for albums
                            if shouldShowAlbums && albums.isEmpty {
                                VStack(spacing: DeviceInfo.shared.spacing(1.0)) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title * 2.5))
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    
                                    Text("common.albumsNotFound".localized)
                                        .adaptiveFont(.title)
                                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                    
                                    Text("common.startAnalysisPrompt".localized)
                                        .adaptiveFont(.body)
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, DeviceInfo.shared.spacing(2.0))
                                .adaptivePadding(1.2)
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Empty state for categories
                            if !shouldShowAlbums && categories.isEmpty && !aiAnalysisManager.isAnalyzing {
                                VStack(spacing: DeviceInfo.shared.spacing(1.0)) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title * 2.5))
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    
                                    Text("category.categoriesNotFound".localized)
                                        .adaptiveFont(.title)
                                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                    
                                    Text("category.tryAnalysisAgain".localized)
                                        .adaptiveFont(.body)
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, DeviceInfo.shared.spacing(2.0))
                                .adaptivePadding(1.2)
                            }
                        }
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
            .constrainedToDevice(usePadding: false)
            .navigationTitle("navigation.categories".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        print("🔄 Refresh button tapped")
                        refreshCategories()
                    }) {
                        Image(systemName: themeManager.isDarkMode ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                            .font(.system(size: DeviceInfo.shared.screenSize.fontSize.body, weight: .medium))
                            .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatCount(isRefreshing ? 10 : 0), value: isRefreshing)
                    }
                }
            }
        }
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
        Button(action: {
            print("🎯 Category card tapped: \(category.name)")
            onTap()
        }) {
            VStack(spacing: 0) {
                // Cover Image with rounded top corners (stretches full card width)
                Group {
                    GeometryReader { geo in
                        if let thumbnailPhoto = category.thumbnailPhoto {
                            PhotoImageView(
                                photo: thumbnailPhoto,
                                // Request thumbnail at on-screen pixel size for quality
                                targetSize: CGSize(width: geo.size.width * UIScreen.main.scale,
                                                   height: geo.size.height * UIScreen.main.scale)
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
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
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                    // 16:9 aspect ratio aligns albums & categories visual language
                    .aspectRatio(16.0/9.0, contentMode: .fit)
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
                                .lineLimit(2)
                            
                            Text("common.photosCount".localized(with: category.count))
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
