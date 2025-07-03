import SwiftUI

struct AlbumDetailView: View {
    let album: PhotoAlbum
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var lastLoggedPhotoCount: Int = 0

    // Always fetch the latest photos from PhotoManager in case the album updated after view was presented
    private var photos: [Photo] {
        photoManager.albums.first(where: { $0.title == album.title })?.photos ?? album.photos
    }

    var body: some View {
        Group {
            if photos.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Загрузка фотографий...")
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(photos) { photo in
                            PhotoImageView(photo: photo, targetSize: CGSize(width: 110, height: 110))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    fullScreenPhotoManager.selectedPhoto = photo
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(AppColors.background(for: themeManager.isDarkMode))
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Готово") { dismiss() }
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
            }
        }
        // Full-screen photo presentation – keeps the sheet visible behind
        .fullScreenCover(
            item: Binding<Photo?>(
                get: { fullScreenPhotoManager.selectedPhoto },
                set: { fullScreenPhotoManager.selectedPhoto = $0 }
            )
        ) { photo in
            FullScreenPhotoGalleryView(
                photos: photos,
                initialPhoto: photo,
                photoManager: photoManager
            ) {
                withAnimation(AppAnimations.modal) {
                    fullScreenPhotoManager.selectedPhoto = nil
                }
            }
            .presentationBackground(.clear)
        }
        .onAppear {
            print("📂 AlbumDetailView appeared for album: \(album.title). Initial photo count: \(photos.count)")
            lastLoggedPhotoCount = photos.count
        }
        .onReceive(photoManager.$albums) { _ in
            let currentCount = photos.count
            if currentCount != lastLoggedPhotoCount {
                print("📈 Album \(album.title) photos updated. New count: \(currentCount)")
                lastLoggedPhotoCount = currentCount
            }
        }
    }
}

#Preview {
    let fullScreen = FullScreenPhotoManager()
    let photoManager = PhotoManager()
    NavigationStack {
        AlbumDetailView(album: PhotoAlbum(title: "Preview", photos: []))
            .environmentObject(photoManager)
            .environmentObject(fullScreen)
    }
} 