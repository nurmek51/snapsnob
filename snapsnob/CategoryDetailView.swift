import SwiftUI

struct CategoryDetailView: View {
    let category: PhotoCategory
    let aiAnalysisManager: AIAnalysisManager
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    // Multi-selection state
    @State private var isSelecting = false
    @State private var selectedPhotos: Set<Photo> = []
    // Toast notification state
    @StateObject private var toastManager = ToastManager()
    
    // Real photos for the category from AI analysis, filtered to exclude trashed photos
    private var categoryPhotos: [Photo] {
        (photoManager.categorizedPhotos[category] ?? []).filter { !$0.isTrashed }
    }
    
    var body: some View {
        SelectablePhotoGrid(
            photos: categoryPhotos,
            selected: $selectedPhotos,
            isSelecting: $isSelecting
        ) { tappedPhoto in
            fullScreenPhotoManager.selectedPhoto = tappedPhoto
        }
        .constrainedToDevice(usePadding: false)
        .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
        .navigationTitle(category.localizedName)
        .navigationBarTitleDisplayMode(.large)
        // Toast notification overlay
        .overlay(
            ToastView(message: toastManager.toastMessage, isShowing: $toastManager.isShowingToast)
                .environmentObject(themeManager)
                .zIndex(1000)
        )
        // Full-screen handled globally by ContentView
        .toolbar {
            // Leading: always 'Готово' to close view
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.done".localized) {
                    if isSelecting {
                        // Reset selection but stay on screen
                        isSelecting = false
                        selectedPhotos.removeAll()
                    } else {
                        dismiss()
                    }
                }
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
            }

            // Trailing: 'Выбрать' when idle; 'Выбрать все' + Trash when selecting
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isSelecting {
                    Button("album.selectAll".localized) {
                        selectedPhotos = Set(categoryPhotos)
                    }

                    Button(role: .destructive) {
                        let selectedCount = selectedPhotos.count
                        for photo in selectedPhotos {
                            photoManager.moveToTrash(photo)
                        }
                        
                        // Show toast notification
                        let message = selectedCount == 1 ? 
                            "toast.photoAddedToTrash".localized : 
                            "toast.photosAddedToTrash".localized(with: selectedCount)
                        toastManager.showToast(message: message)
                        
                        isSelecting = false
                        selectedPhotos.removeAll()
                    } label: {
                        Image(systemName: "trash")
                    }
                } else {
                    Button("album.select".localized) { isSelecting = true }
                }
            }
        }
        // Full-screen photo presentation is now handled globally by ContentView.
    }
}

#Preview {
    let photoManager = PhotoManager()
    let fullScreen = FullScreenPhotoManager()
    NavigationView {
        CategoryDetailView(
            category: PhotoCategory.nature,
            aiAnalysisManager: AIAnalysisManager(photoManager: photoManager)
        )
        .environmentObject(photoManager)
        .environmentObject(fullScreen)
    }
}
