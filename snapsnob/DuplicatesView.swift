import SwiftUI
import Photos

struct NewDuplicatesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let photoManager: PhotoManager
    @ObservedObject var aiManager: AIAnalysisManager
    let onPhotoTap: (Photo) -> Void
    
    @State private var selectedToKeep: Set<UUID> = []
    @State private var showingDeleteAlert = false
    @State private var showingDeleteProgress = false
    @State private var deletionProgress: Double = 0.0
    @State private var deletionCompleted = false
    @State private var showingUndoWindow = false
    @State private var undoTimer: Timer?
    @State private var deletedPhotos: [Photo] = []
    
    // Calculate storage space that can be freed
    private var storageToFree: String {
        let duplicatesToDelete = duplicateGroups.flatMap { group in
            group.filter { !selectedToKeep.contains($0.id) }
        }
        
        // Estimate average file size (this would be more accurate with actual file sizes)
        let estimatedSize = duplicatesToDelete.count * 3 // 3MB average per photo
        
        if estimatedSize < 1024 {
            return "\(estimatedSize) MB"
        } else {
            return String(format: "%.1f GB", Double(estimatedSize) / 1024.0)
        }
    }
    
    private var duplicateGroups: [[Photo]] {
        aiManager.duplicateGroups
    }
    
    private var totalDuplicates: Int {
        duplicateGroups.reduce(0) { total, group in
            total + (group.count - 1) // -1 because we keep one from each group
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Content
            if duplicateGroups.isEmpty {
                emptyStateSection
            } else {
                duplicatesContentSection
            }
        }
        .constrainedToDevice(usePadding: false)
        .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
        .alert("Удалить дубликаты?", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                deleteSelectedDuplicates()
            }
        } message: {
            Text("Будет удалено \(totalDuplicates) дубликатов. Освободится \(storageToFree) места. Оригиналы будут сохранены.")
        }
        .sheet(isPresented: $showingDeleteProgress) {
            deletionProgressSheet
        }
        .onAppear {
            initializeSelections()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Title and Stats
            VStack(spacing: 12) {
                Text("Duplicate Photos")
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .largeTitle : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                
                // Statistics
                HStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16) {
                    DuplicateStatBadge(
                        title: "Групп дубликатов",
                        value: "\(duplicateGroups.count)",
                        icon: "doc.on.doc",
                        color: .blue
                    )
                    
                    DuplicateStatBadge(
                        title: "Можно удалить",
                        value: "\(totalDuplicates)",
                        icon: "trash",
                        color: .red
                    )
                    
                    DuplicateStatBadge(
                        title: "Освободится",
                        value: storageToFree,
                        icon: "internaldrive",
                        color: .green
                    )
                }
            }
            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
            .padding(.top, UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16)
            
            // Bulk Delete Button
            if !duplicateGroups.isEmpty {
                bulkDeleteButton
            }
        }
        .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16)
    }
    
    private var bulkDeleteButton: some View {
        Button(action: {
            showingDeleteAlert = true
        }) {
            HStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12) {
                Image(systemName: "trash.fill")
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title2 : .headline)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Удалить все дубликаты")
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Освободить \(storageToFree) места")
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title : .title2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 30 : 24)
            .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16)
            .background(
                LinearGradient(
                    colors: [.red, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16))
            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 100 : 80))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("Дубликатов не найдено")
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .largeTitle : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Отличная работа! В вашей библиотеке нет дубликатов фотографий.")
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .body)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 60 : 40)
    }
    
    private var duplicatesContentSection: some View {
        ScrollView {
            VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 32 : 24) {
                ForEach(Array(duplicateGroups.enumerated()), id: \.offset) { groupIndex, group in
                    NewDuplicateGroupCard(
                        group: group,
                        groupIndex: groupIndex + 1,
                        selectedToKeep: $selectedToKeep,
                        photoManager: photoManager,
                        onPhotoTap: onPhotoTap
                    )
                }
            }
            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
            .padding(.top, UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16)
            .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 40 : 32)
        }
    }
    
    private var deletionProgressSheet: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("Удаление дубликатов...")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                ProgressView(value: deletionProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .red))
                    .frame(height: 8)
                
                Text("\(Int(deletionProgress * 100))% завершено")
                    .font(.body)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
            }
            
            if deletionCompleted {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("Дубликаты удалены успешно!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Button("Готово") {
                        showingDeleteProgress = false
                        deletionCompleted = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(40)
        .interactiveDismissDisabled(!deletionCompleted)
    }
    
    // MARK: - Functions
    
    private func initializeSelections() {
        // Auto-select the best photo from each group
        for group in aiManager.duplicateGroups {
            if let bestPhoto = group.sorted(by: { $0.qualityScore > $1.qualityScore }).first {
                selectedToKeep.insert(bestPhoto.id)
            }
        }
    }
    
    private func deleteSelectedDuplicates() {
        showingDeleteProgress = true
        deletionProgress = 0.0
        
        let duplicatesToDelete = aiManager.duplicateGroups.flatMap { group in
            group.filter { !selectedToKeep.contains($0.id) }
        }
        
        deletedPhotos = duplicatesToDelete
        
        // Simulate deletion progress
        let totalCount = duplicatesToDelete.count
        var deletedCount = 0
        
        let _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            deletedCount += 1
            deletionProgress = Double(deletedCount) / Double(totalCount)
            
            if deletedCount >= totalCount {
                timer.invalidate()
                completeDeletion()
            }
        }
    }
    
    private func completeDeletion() {
        deletionCompleted = true
        
        // Move photos to trash
        for photo in deletedPhotos {
            photoManager.moveToTrash(photo)
        }
        
        // Clear duplicate groups that are now empty
        aiManager.duplicateGroups = aiManager.duplicateGroups.filter { group in
            group.contains { selectedToKeep.contains($0.id) }
        }
        
        // Show undo window
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if deletionCompleted {
                showUndoWindow()
            }
        }
    }
    
    private func showUndoWindow() {
        showingUndoWindow = true
        
        undoTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            showingUndoWindow = false
        }
    }
    
    private func undoDeletion() {
        undoTimer?.invalidate()
        showingUndoWindow = false
        
        // Restore photos from trash
        for photo in deletedPhotos {
            photoManager.restoreFromTrash(photo)
        }
        
        // Refresh duplicate detection
                                aiManager.analyzeAllPhotos()
        
        deletedPhotos.removeAll()
    }
}

// MARK: - New Duplicate Group Card
struct NewDuplicateGroupCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let group: [Photo]
    let groupIndex: Int
    @Binding var selectedToKeep: Set<UUID>
    let photoManager: PhotoManager
    let onPhotoTap: (Photo) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Group Header
            HStack {
                Text("Duplicate Group \(groupIndex)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                
                Text("(\(group.count) photos)")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                
                Spacer()
                
                Text("Keep 1, Delete \(group.count - 1)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.red.opacity(0.1))
                    )
            }
            
            // Photos Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 12) {
                ForEach(group, id: \.id) { photo in
                    NewDuplicatePhotoCard(
                        photo: photo,
                        photoManager: photoManager,
                        isSelected: selectedToKeep.contains(photo.id),
                        onTap: {
                            onPhotoTap(photo)
                        },
                        onSelectionToggle: {
                            toggleSelection(for: photo)
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.border(for: themeManager.isDarkMode), lineWidth: 1)
        )
    }
    
    private func toggleSelection(for photo: Photo) {
        if selectedToKeep.contains(photo.id) {
            // Ensure at least one photo is selected per group
            let groupSelected = group.filter { selectedToKeep.contains($0.id) }
            if groupSelected.count > 1 {
                selectedToKeep.remove(photo.id)
            }
        } else {
            // Remove other selections from this group and select this one
            for p in group {
                selectedToKeep.remove(p.id)
            }
            selectedToKeep.insert(photo.id)
        }
    }
}

// MARK: - New Duplicate Photo Card
struct NewDuplicatePhotoCard: View {
    let photo: Photo
    let photoManager: PhotoManager
    let isSelected: Bool
    let onTap: () -> Void
    let onSelectionToggle: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Photo
                PhotoImageView(
                    photo: photo,
                    targetSize: CGSize(width: 110, height: 110)
                )
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Selection Overlay
                if !isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.5))
                        .overlay(
                            VStack {
                                Image(systemName: "trash.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text("DELETE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        )
                }
                
                // Info Overlays
                VStack {
                    HStack {
                        // Keep/Delete badge
                        Button(action: onSelectionToggle) {
                            HStack(spacing: 4) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? .green : .white)
                                    .font(.system(size: 16))
                                
                                Text(isSelected ? "KEEP" : "DELETE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(isSelected ? .green : .white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isSelected ? .white : .black.opacity(0.7))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(6)
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Photo info
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            // Quality score
                            Text("⭐ \(String(format: "%.1f", photo.qualityScore))")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            // Resolution
                            Text("\(photo.asset.pixelWidth)×\(photo.asset.pixelHeight)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            
                            // Date
                            Text(formatDate(photo.creationDate))
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.7))
                    )
                    .padding(6)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Handle press completion
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: date)
    }
}

#Preview {
    let mockPhotoManager = PhotoManager()
    let mockAIManager = AIAnalysisManager(photoManager: mockPhotoManager)
    
    NewDuplicatesView(
        photoManager: mockPhotoManager,
        aiManager: mockAIManager
    ) { photo in
        print("Photo tapped: \(photo.id)")
    }
}

// MARK: - Duplicate Stat Badge
struct DuplicateStatBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

struct DuplicatesView: View {
    @StateObject private var photoManager = PhotoManager()
    @StateObject private var aiAnalysisManager = AIAnalysisManager(photoManager: PhotoManager())

    var body: some View {
        NewDuplicatesView(
            photoManager: photoManager,
            aiManager: aiAnalysisManager,
            onPhotoTap: { photo in }
        )
        .onAppear {
                                    aiAnalysisManager.analyzeAllPhotos()
        }
    }
}