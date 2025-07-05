import SwiftUI

struct CategoryBottomSheet: View {
    let category: PhotoCategory
    let photoManager: PhotoManager
    let aiAnalysisManager: AIAnalysisManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    
    // Real photos with AI ratings for the category
    private var categoryPhotos: [Photo] {
        photoManager.categorizedPhotos[category] ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                // Category Header
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: category.icon)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .font(.system(size: 24, weight: .semibold))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        
                        Text("\(categoryPhotos.count) фото")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                Divider()
                    .padding(.horizontal, 20)
            }
            
            // Photos Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 16) {
                    ForEach(categoryPhotos) { photo in
                        PhotoCard(photo: photo) {
                            withAnimation(AppAnimations.modal) {
                                fullScreenPhotoManager.selectedPhoto = photo
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
        // Full-screen handled globally by ContentView
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

struct PhotoCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let photo: Photo
    let onTap: () -> Void
    @State private var isPressed = false
    
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
            
            // Photo quality indicator (using AI quality score)
            HStack(spacing: 2) {
                let qualityStars = Int(round(photo.qualityScore * 5))
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= qualityStars ? "star.fill" : "star")
                        .foregroundColor(star <= qualityStars ? AppColors.accent(for: themeManager.isDarkMode) : AppColors.secondaryText(for: themeManager.isDarkMode).opacity(0.4))
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Handle press completion
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

#Preview {
    let photoManager = PhotoManager()
    CategoryBottomSheet(
        category: PhotoCategory.nature,
        photoManager: photoManager,
        aiAnalysisManager: AIAnalysisManager(photoManager: photoManager)
    )
}
