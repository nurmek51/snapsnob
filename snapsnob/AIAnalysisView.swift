import SwiftUI

// MARK: - Shimmer Modifier
private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.4), Color.white.opacity(0.15)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(25))
                    .offset(x: phase * 350)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

private extension View {
    func shimmering() -> some View { self.modifier(Shimmer()) }
}

struct AIAnalysisView: View {
    let onDismiss: () -> Void
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var aiAnalysisManager: AIAnalysisManager
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    @State private var showingDeleteDuplicatesAlert = false
    @State private var showingDuplicates = false
    @State private var selectedCategory: PhotoCategory?
    
    // Computed properties for Vision analysis results
    private var visionCategories: [VisionCategory] {
        // Exclude trashed photos to keep counts in sync with the main Categories view
        let categorizedPhotosFiltered = photoManager.categorizedPhotos.mapValues { photos in
            photos.filter { !$0.isTrashed }
        }

        return categorizedPhotosFiltered.compactMap { category, photos -> VisionCategory? in
            guard !photos.isEmpty else { return nil }

            // Build a preview array with first few photos for better visualization
            let preview = photos.prefix(4).map { photo -> VisionPhoto in
                VisionPhoto(
                    photo: photo,
                    confidence: Int(photo.categoryConfidence * 100),
                    category: category.rawValue
                )
            }
            return VisionCategory(
                name: category.rawValue,
                photos: preview,
                totalCount: photos.count
            )
        }.sorted { $0.totalCount > $1.totalCount }
    }
    
    private var duplicateGroups: [DuplicateGroup] {
        aiAnalysisManager.duplicateGroups.enumerated().map { index, group in
            DuplicateGroup(
                id: index,
                type: getDuplicateGroupType(for: group),
                photos: group,
                count: group.count
            )
        }
    }
    
    private func getDuplicateGroupType(for photos: [Photo]) -> String {
        guard !photos.isEmpty else { return "Дубликаты" }
        
        // Анализируем тип дубликатов
        let assets = photos.map { $0.asset }
        
        // Проверяем, есть ли фото с одинаковыми размерами
        let firstAsset = assets.first!
        let hasSameDimensions = assets.allSatisfy { 
            $0.pixelWidth == firstAsset.pixelWidth && $0.pixelHeight == firstAsset.pixelHeight 
        }
        
        if hasSameDimensions {
            // Проверяем источники фото
            let hasImportedPhotos = assets.contains { $0.sourceType == .typeUserLibrary }
            
            if hasImportedPhotos {
                return "Скачанные дубликаты"
            } else {
                return "Точные дубликаты"
            }
        } else {
            return "Похожие фото"
        }
    }
    
    // MARK: - Section Builders to reduce body complexity
    @ViewBuilder
    private var analysisStatusSection: some View {
        VStack(spacing: DeviceInfo.shared.spacing(0.8)) {
            if aiAnalysisManager.isAnalyzing {
                analyzingStatusView
            } else {
                readyToAnalyzeView
            }
        }
        .adaptivePadding(1.2)
    }

    @ViewBuilder
    private var categoriesSection: some View {
        if !visionCategories.isEmpty {
            VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.8)) {
                categoryHeader
                categoryGrid
            }
        }
    }

    @ViewBuilder
    private var duplicatesSection: some View {
        // Section removed – duplicates now accessed from toolbar
        EmptyView()
    }

    // MARK: - Smaller UI components
    private var analyzingStatusView: some View {
        VStack(spacing: DeviceInfo.shared.spacing(0.6)) {
            analyzingHeader
            analyzingProgress
        }
        .adaptivePadding(1.2)
        .background(statusBackground)
    }

    private var readyToAnalyzeView: some View {
        VStack(spacing: DeviceInfo.shared.spacing(0.8)) {
            readyHeader
            // Кнопка запуска анализа больше не нужна, анализ запускается автоматически
            // startAnalyzeButton
        }
        .adaptivePadding(1.2)
        .background(statusBackground)
    }

    private var analyzingHeader: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                .adaptiveFont(.title)
            VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.2)) {
                Text("Анализ фотографий")
                    .adaptiveFont(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                Text("Используется Apple Vision для категоризации")
                    .adaptiveFont(.caption)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
            }
            Spacer()
        }
    }

    private var analyzingProgress: some View {
        VStack(spacing: DeviceInfo.shared.spacing(0.3)) {
            ProgressView(value: aiAnalysisManager.analysisProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: AppColors.accent(for: themeManager.isDarkMode)))
                .scaleEffect(y: 2)
            HStack {
                Text("\(Int(aiAnalysisManager.analysisProgress * 100))% завершено")
                    .adaptiveFont(.caption)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                Spacer()
                Text(aiAnalysisManager.cacheStatus)
                    .adaptiveFont(.caption)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
            }
        }
    }

    private var readyHeader: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                .adaptiveFont(.title)
            VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.2)) {
                Text("Готов к анализу")
                    .adaptiveFont(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                Text("\(photoManager.allPhotos.count) фотографий в галерее")
                    .adaptiveFont(.caption)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
            }
            Spacer()
        }
    }

    private var startAnalyzeButton: some View {
        Button(action: { aiAnalysisManager.analyzeAllPhotos() }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Начать анализ")
            }
            .adaptiveFont(.body)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .adaptivePadding(0.8)
            .background(AppColors.accent(for: themeManager.isDarkMode))
            .clipShape(RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius))
        }
    }

    private var statusBackground: some View {
        RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
            .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
            .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 8, x: 0, y: 2)
    }

    private var categoryHeader: some View {
        HStack {
            Text("Найденные категории")
                .adaptiveFont(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
            Spacer()
            Text("\(visionCategories.count)")
                .adaptiveFont(.caption)
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                .padding(.horizontal, DeviceInfo.shared.spacing(0.6))
                .padding(.vertical, DeviceInfo.shared.spacing(0.3))
                .background(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                .clipShape(Capsule())
        }
        .adaptivePadding(1.2)
    }

    // MARK: - Adaptive grid layout matching CategoriesView
    private var categoryGridColumns: [GridItem] {
        let device = DeviceInfo.shared.screenSize
        let limit: Int
        switch device {
        case .compact, .standard, .plus, .max:
            limit = 2
        case .iPad:
            limit = 4
        case .iPadPro:
            limit = 5
        }
        let columns = max(1, min(visionCategories.count, limit))
        return Array(repeating: GridItem(.flexible(), spacing: DeviceInfo.shared.screenSize.gridSpacing), count: columns)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: categoryGridColumns, spacing: DeviceInfo.shared.screenSize.gridSpacing) {
            ForEach(visionCategories) { category in
                Button {
                    if let pc = PhotoCategory(rawValue: category.name) {
                        withAnimation(AppAnimations.modal) {
                            selectedCategory = pc
                        }
                    }
                } label: {
                    CategoryResultCard(category: category)
                        .environmentObject(themeManager)
                }
                .buttonStyle(PlainButtonStyle())
                .id(category.id)
            }
        }
        .padding(.horizontal, DeviceInfo.shared.screenSize.horizontalPadding)
    }

    // Removed standalone duplicates header/button – replaced by toolbar
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DeviceInfo.shared.spacing(1.2)) {
                    Spacer().frame(height: DeviceInfo.shared.spacing(1.0))
                    ZStack {
                        analysisStatusSection
                        if aiAnalysisManager.isAnalyzing {
                            analysisStatusSection
                                .shimmering()
                        }
                    }
                    
                    categoriesSection
                    
                    duplicatesSection
                }
                .padding(.bottom, DeviceInfo.shared.spacing(2.0))
            }
            .navigationTitle("Анализ Apple Vision")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                // Close button on the left
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    .accessibilityLabel("Закрыть")
                }

                // Duplicates access on the right (always visible)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingDuplicates = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "doc.on.doc")
                            if aiAnalysisManager.duplicateGroups.count > 0 {
                                Text("\(aiAnalysisManager.duplicateGroups.count)")
                                    .font(.system(size: 9))
                                    .padding(4)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -6)
                            }
                        }
                    }
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    .accessibilityLabel("Дубликаты")
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingDuplicates) {
            DuplicatesView()
                .environmentObject(photoManager)
                .environmentObject(fullScreenPhotoManager)
                .environmentObject(themeManager)
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
        .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea())
        .onAppear {
            // Теперь всегда запускаем анализ при появлении, даже если кэш валиден
            if !aiAnalysisManager.isAnalyzing {
                aiAnalysisManager.analyzeAllPhotos()
            }
        }
    }
    
    // MARK: - Enhanced Analysis Status Display
    private var enhancedAnalysisStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Analysis Status")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                
                Spacer()
                
                Button(action: {
                    #if targetEnvironment(simulator)
                    aiAnalysisManager.enableSimulatorSafeMode()
                    #else
                    aiAnalysisManager.enableHighPerformanceMode()
                    #endif
                }) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            let status = aiAnalysisManager.getDetailedAnalysisStatus()
            
            VStack(alignment: .leading, spacing: 8) {
                // Progress bar with detailed info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress: \(Int(status.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        
                        Spacer()
                        
                        if status.isRunning {
                            Text("ETA: \(status.estimatedTimeRemaining)")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                    }
                    
                    ProgressView(value: status.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(x: 1, y: 0.8)
                }
                
                // Performance metrics
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Processed")
                            .font(.caption2)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        Text("\(status.photosProcessed)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text("Classified")
                            .font(.caption2)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        Text("\(status.classificationsFound)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Speed")
                            .font(.caption2)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        Text(status.throughput)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                // Processing mode indicator
                HStack {
                    Circle()
                        .fill(status.isRunning ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    
                    Text("Mode: \(status.currentMode)")
                        .font(.caption2)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Vision-specific Data Models
struct VisionCategory: Identifiable {
    let id = UUID()
    let name: String
    let photos: [VisionPhoto]
    let totalCount: Int
}

struct VisionPhoto: Identifiable {
    let id = UUID()
    let photo: Photo
    let confidence: Int
    let category: String
    
    init(photo: Photo, confidence: Int, category: String) {
        self.photo = photo
        self.confidence = confidence
        self.category = category
    }
}

struct DuplicateGroup: Identifiable {
    let id: Int
    let type: String
    let photos: [Photo]
    let count: Int
}

// MARK: - Vision Categories View
struct VisionCategoriesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let categories: [VisionCategory]
    let onCategoryTap: (String) -> Void
    let onPhotoTap: (Photo) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if categories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        
                        Text("Категории не найдены")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Запустите анализ для категоризации фотографий")
                            .font(.body)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(categories) { category in
                        VisionCategoryCard(
                            category: category,
                            onCategoryTap: onCategoryTap,
                            onPhotoTap: onPhotoTap
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Vision Category Card
struct VisionCategoryCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let category: VisionCategory
    let onCategoryTap: (String) -> Void
    let onPhotoTap: (Photo) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(category.totalCount)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Capsule())
                // Removed chevron button to make card non-interactive
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(category.photos) { visionPhoto in
                        Button(action: {
                            onPhotoTap(visionPhoto.photo)
                        }) {
                            VStack(spacing: 4) {
                                PhotoImageView(photo: visionPhoto.photo, targetSize: CGSize(width: 80, height: 80))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text("\(visionPhoto.confidence)%")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Vision Duplicates View
struct VisionDuplicatesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let duplicateGroups: [DuplicateGroup]
    let onDeleteDuplicates: () -> Void
    let onPhotoTap: (Photo) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if duplicateGroups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundColor(themeManager.isDarkMode ? .white : .green)
                        
                        Text("Дубликаты не найдены")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("У вас нет дублирующихся фотографий")
                            .font(.body)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    }
                    .padding(.top, 60)
                } else {
                    // Delete all button
                    Button(action: onDeleteDuplicates) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Удалить все дубликаты")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    
                    ForEach(duplicateGroups) { group in
                        VisionDuplicateGroupCard(
                            group: group,
                            onPhotoTap: onPhotoTap
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Vision Duplicate Group Card
struct VisionDuplicateGroupCard: View {
    let group: DuplicateGroup
    let onPhotoTap: (Photo) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(group.type)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(group.count) фото")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.photos) { photo in
                        Button(action: {
                            onPhotoTap(photo)
                        }) {
                            PhotoImageView(photo: photo, targetSize: CGSize(width: 80, height: 80))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Vision Category Photos View
struct VisionCategoryPhotosView: View {
    let category: PhotoCategory
    let aiAnalysisManager: AIAnalysisManager
    let onDismiss: () -> Void
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var photoManager: PhotoManager
    
    private var categoryPhotos: [Photo] {
        photoManager.categorizedPhotos[category] ?? []
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 2) {
                    ForEach(categoryPhotos) { photo in
                        PhotoImageView(photo: photo, targetSize: CGSize(width: 120, height: 120))
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            .onTapGesture {
                                withAnimation(AppAnimations.modal) {
                                    fullScreenPhotoManager.selectedPhoto = photo
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Готово") {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - CategoryResultCard Component
struct CategoryResultCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let category: VisionCategory
    
    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail grid (showing up to 4 photos)
            Group {
                if category.photos.count == 1 {
                    // Single photo
                    PhotoImageView(
                        photo: category.photos[0].photo,
                        targetSize: CGSize(width: 200, height: 200)
                    )
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                } else if category.photos.count >= 2 {
                    // Grid of photos
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 2), spacing: 1) {
                        ForEach(Array(category.photos.prefix(4).enumerated()), id: \.offset) { index, visionPhoto in
                            PhotoImageView(
                                photo: visionPhoto.photo,
                                targetSize: CGSize(width: 100, height: 100)
                            )
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                        }
                    }
                } else {
                    // Fallback placeholder
                    Rectangle()
                        .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        )
                }
            }
            .frame(height: 120)
            .clipShape(
                .rect(
                    topLeadingRadius: DeviceInfo.shared.screenSize.cornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: DeviceInfo.shared.screenSize.cornerRadius
                )
            )
            
            // Category info
            VStack(spacing: DeviceInfo.shared.spacing(0.3)) {
                HStack {
                    VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.1)) {
                        Text(category.name)
                            .adaptiveFont(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                            .lineLimit(1)
                        
                        Text("\(category.totalCount) фото")
                            .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption * 0.9))
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    }
                    
                    Spacer()
                    
                    // Confidence indicator
                    if let firstPhoto = category.photos.first {
                        Text("\(firstPhoto.confidence)%")
                            .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption * 0.8))
                            .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                            .padding(.horizontal, DeviceInfo.shared.spacing(0.4))
                            .padding(.vertical, DeviceInfo.shared.spacing(0.2))
                            .background(AppColors.accent(for: themeManager.isDarkMode).opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(DeviceInfo.shared.spacing(0.8))
            .background(AppColors.cardBackground(for: themeManager.isDarkMode))
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: DeviceInfo.shared.screenSize.cornerRadius,
                    bottomTrailingRadius: DeviceInfo.shared.screenSize.cornerRadius,
                    topTrailingRadius: 0
                )
            )
        }
        .background(
            RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 8, x: 0, y: 2)
        )
    }
}

#Preview {
    AIAnalysisView {
        // Dismiss action
    }
}
