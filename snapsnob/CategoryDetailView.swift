import SwiftUI

struct CategoryDetailView: View {
    let category: PhotoCategory
    let aiAnalysisManager: AIAnalysisManager
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    // Real photos for the category from AI analysis
    private var categoryPhotos: [Photo] {
        photoManager.categorizedPhotos[category] ?? []
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(categoryPhotos) { photo in
                    PhotoImageView(
                        photo: photo,
                        targetSize: CGSize(width: 110, height: 110)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        fullScreenPhotoManager.selectedPhoto = photo
                    }
                }
            }
            .padding()
        }
        .background(AppColors.background(for: themeManager.isDarkMode))
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.large)
        // Full-screen handled globally by ContentView
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Готово") {
                    dismiss()
                }
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
            }
        }
        // Full-screen photo presentation over this sheet, keeping it visible behind.
        .fullScreenCover(
            item: Binding<Photo?>(
                get: { fullScreenPhotoManager.selectedPhoto },
                set: { fullScreenPhotoManager.selectedPhoto = $0 }
            )
        ) { photo in
            FullScreenPhotoGalleryView(
                photos: categoryPhotos,
                initialPhoto: photo,
                photoManager: photoManager
            ) {
                withAnimation(AppAnimations.modal) {
                    fullScreenPhotoManager.selectedPhoto = nil
                }
            }
            .presentationBackground(.clear)
        }
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
