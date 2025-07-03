import SwiftUI

struct AIAnalysisView: View {
    let onDismiss: () -> Void
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var aiAnalysisManager: AIAnalysisManager
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    @State private var showingDeleteDuplicatesAlert = false
    @State private var selectedCategory: PhotoCategory?
    @State private var showingCategoryPhotos = false
    
    // Computed properties for Vision analysis results
    private var visionCategories: [VisionCategory] {
        // Exclude trashed photos to keep counts in sync with the main Categories view
        let categorizedPhotosFiltered = photoManager.categorizedPhotos.mapValues { photos in
            photos.filter { !$0.isTrashed }
        }

        return categorizedPhotosFiltered.compactMap { category, photos -> VisionCategory? in
            guard !photos.isEmpty else { return nil }

            // Build a preview array with at most 6 photos, but keep total for accurate display
            let preview = photos.prefix(6).map { photo -> VisionPhoto in
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Button("Закрыть") {
                            onDismiss()
                        }
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("Анализ Apple Vision")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Empty space to maintain layout balance
                        Text("")
                            .frame(width: 70) // Approximate width of removed button
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Analysis Progress
                    if aiAnalysisManager.isAnalyzing {
                        VStack(spacing: 12) {
                            ProgressView(value: aiAnalysisManager.analysisProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(height: 4)
                            
                            Text("Apple Vision анализирует фотографии... \(Int(aiAnalysisManager.analysisProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            
                            // Cache status during analysis
                            if !aiAnalysisManager.cacheStatus.isEmpty {
                                Text(aiAnalysisManager.cacheStatus)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Cache Information (when not analyzing)
                    if !aiAnalysisManager.isAnalyzing && aiAnalysisManager.hasAnalysisResults {
                        VStack(spacing: 8) {
                            let cacheInfo = aiAnalysisManager.getCacheInfo()
                            let stats = aiAnalysisManager.getAnalysisStats()
                            
                            HStack(spacing: 16) {
                                // Analysis stats
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Проанализировано: \(stats.total)")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                    
                                    if cacheInfo.count > 0 {
                                        Text("В кэше: \(cacheInfo.count)")
                                            .font(.caption2)
                                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                    }
                                }
                                
                                Spacer()
                                
                                // Cache actions
                                HStack(spacing: 12) {
                                    Button("Очистить кэш") {
                                        aiAnalysisManager.clearCache()
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    
                                    Button("Пересканировать") {
                                        aiAnalysisManager.forceReanalyze()
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                }
                            }
                            
                            // Cache status
                            if !aiAnalysisManager.cacheStatus.isEmpty {
                                Text(aiAnalysisManager.cacheStatus)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(AppColors.cardBackground(for: themeManager.isDarkMode))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                    }
                    
                    // Tab Selector
                    if !aiAnalysisManager.isAnalyzing {
                        Picker("Тип анализа", selection: $selectedTab) {
                            Text("Категории Vision").tag(0)
                            Text("Дубликаты").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 16)
                
                Divider()
                
                // Content
                if aiAnalysisManager.isAnalyzing {
                    // Analysis in progress
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "eye.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .scaleEffect(aiAnalysisManager.isAnalyzing ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: aiAnalysisManager.isAnalyzing)
                        
                        Text("Apple Vision анализирует ваши фотографии")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text("Максимальная точность и качество")
                            .font(.body)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    // Analysis results
                    TabView(selection: $selectedTab) {
                        // Vision Categories Tab
                        VisionCategoriesView(
                            categories: visionCategories,
                            onCategoryTap: { category in
                                withAnimation(AppAnimations.modal) {
                                    selectedCategory = PhotoCategory.allCases.first { $0.rawValue == category }
                                    showingCategoryPhotos = true
                                }
                            },
                            onPhotoTap: { photo in
                                withAnimation(AppAnimations.modal) {
                                    fullScreenPhotoManager.selectedPhoto = photo
                                }
                            }
                        )
                        .tag(0)
                        
                        // Duplicates Tab
                        VisionDuplicatesView(
                            duplicateGroups: duplicateGroups,
                            onDeleteDuplicates: {
                                showingDeleteDuplicatesAlert = true
                            },
                            onPhotoTap: { photo in
                                withAnimation(AppAnimations.modal) {
                                    fullScreenPhotoManager.selectedPhoto = photo
                                }
                            }
                        )
                        .tag(1)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .background(AppColors.background(for: themeManager.isDarkMode))
            .navigationBarHidden(true)
            .onAppear {
                print("[AIAnalysisView] appeared – categorized count: \(photoManager.categorizedPhotos.count), inProgress: \(aiAnalysisManager.isAnalyzing)")
                startAnalysisIfNeeded()
            }
            .alert("Удалить дубликаты", isPresented: $showingDeleteDuplicatesAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    deleteDuplicates()
                }
            } message: {
                Text("Вы уверены, что хотите удалить все найденные дубликаты? Это действие нельзя отменить.")
            }
            .sheet(isPresented: $showingCategoryPhotos) {
                if let category = selectedCategory {
                    VisionCategoryPhotosView(category: category, aiAnalysisManager: aiAnalysisManager) {
                        withAnimation(AppAnimations.modal) {
                            showingCategoryPhotos = false
                            selectedCategory = nil
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
                }
            }
        }
    }
    
    private func startAnalysisIfNeeded() {
        // Ensure we only start analysis when we actually have photos ready
        guard !aiAnalysisManager.isAnalyzing else { return }

        // If the PhotoManager has finished loading and we already have photos – start immediately
        if !photoManager.isLoading && !photoManager.allPhotos.isEmpty {
            aiAnalysisManager.analyzeAllPhotos()
            return
        }

        // Otherwise poll until the PhotoManager finishes loading and the library is non-empty
        Task {
            // Poll every 100 ms — lightweight and avoids extra Combine plumbing
            while photoManager.isLoading || photoManager.allPhotos.isEmpty {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
            }
            // Start analysis on the main actor once the prerequisites are satisfied
            await MainActor.run {
                if !aiAnalysisManager.isAnalyzing {
                    aiAnalysisManager.analyzeAllPhotos()
                }
            }
        }
    }
    
    private func startAnalysis() {
        aiAnalysisManager.analyzeAllPhotos()
    }
    
    private func deleteDuplicates() {
        print("🗑️ Deleting duplicates...")
        
        // Delete all duplicates except the first (best quality) photo in each group
        for group in aiAnalysisManager.duplicateGroups {
            let photosToDelete = Array(group.dropFirst()) // Keep first (best quality) photo
            
            for photo in photosToDelete {
                photoManager.moveToTrash(photo)
            }
        }
        
        print("🗑️ Moved \(aiAnalysisManager.duplicateGroups.reduce(0) { $0 + ($1.count - 1) }) duplicate photos to trash")
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
                
                Button(action: {
                    onCategoryTap(category.name)
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
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
            .navigationTitle(category.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AIAnalysisView {
        // Dismiss action
    }
}
