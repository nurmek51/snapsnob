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
    
    // Real photos for the category from AI analysis
    private var categoryPhotos: [Photo] {
        photoManager.categorizedPhotos[category] ?? []
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
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.large)
        // Full-screen handled globally by ContentView
        .toolbar {
            // Leading: always 'Готово' to close view
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Готово") {
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
                    Button("Выбрать все") {
                        selectedPhotos = Set(categoryPhotos)
                    }

                    Button(role: .destructive) {
                        for photo in selectedPhotos {
                            photoManager.moveToTrash(photo)
                        }
                        isSelecting = false
                        selectedPhotos.removeAll()
                    } label: {
                        Image(systemName: "trash")
                    }
                } else {
                    Button("Выбрать") { isSelecting = true }
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
