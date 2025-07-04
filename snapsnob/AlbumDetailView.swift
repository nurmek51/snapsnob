import SwiftUI

struct AlbumDetailView: View {
    let album: PhotoAlbum
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var lastLoggedPhotoCount: Int = 0
    // Multi-selection state
    @State private var isSelecting = false
    @State private var selectedPhotos: Set<Photo> = []

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
                SelectablePhotoGrid(
                    photos: photos,
                    selected: $selectedPhotos,
                    isSelecting: $isSelecting
                ) { tapped in
                    fullScreenPhotoManager.selectedPhoto = tapped
                }
            }
        }
        .background(AppColors.background(for: themeManager.isDarkMode))
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Готово") {
                    if isSelecting {
                        isSelecting = false
                        selectedPhotos.removeAll()
                    } else {
                        dismiss()
                    }
                }
                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isSelecting {
                    Button("Выбрать все") {
                        selectedPhotos = Set(photos)
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