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
    // Toast notification state
    @StateObject private var toastManager = ToastManager()

    // Always fetch the latest photos from PhotoManager in case the album updated after view was presented
    // Filter out trashed photos to ensure deleted photos are not shown
    private var photos: [Photo] {
        let albumPhotos = photoManager.albums.first(where: { $0.title == album.title })?.photos ?? album.photos
        return albumPhotos.filter { !$0.isTrashed }
    }

    var body: some View {
        Group {
            if photos.isEmpty {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode).opacity(0.3))
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
                .constrainedToDevice(usePadding: false)
            }
        }
        .constrainedToDevice(usePadding: false)
        .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.large)
        // Toast notification overlay
        .overlay(
            ToastView(message: toastManager.toastMessage, isShowing: $toastManager.isShowingToast)
                .environmentObject(themeManager)
                .zIndex(1000)
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.done".localized) {
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
                    Button("album.selectAll".localized) {
                        selectedPhotos = Set(photos)
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