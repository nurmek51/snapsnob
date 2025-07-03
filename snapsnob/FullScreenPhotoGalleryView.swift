import SwiftUI
import Photos

/// A fullscreen gallery that lets the user swipe horizontally between photos while preserving all zoom and dismiss interactions from `FullScreenPhotoView`.
struct FullScreenPhotoGalleryView: View {
    /// Ordered list of photos that should be shown in the gallery.
    let photos: [Photo]
    /// Photo that was originally tapped by the user.
    let initialPhoto: Photo
    /// Shared photo manager – forwarded to every underlying `FullScreenPhotoView` so it can load the asset.
    let photoManager: PhotoManager
    /// Called when the gallery should be dismissed.
    let onDismiss: () -> Void

    /// Index of the currently visible page in `TabView`.
    @State private var currentIndex: Int = 0

    init(photos: [Photo], initialPhoto: Photo, photoManager: PhotoManager, onDismiss: @escaping () -> Void) {
        self.photos = photos
        self.initialPhoto = initialPhoto
        self.photoManager = photoManager
        self.onDismiss = onDismiss
        // Set the initial index inside the State wrapper.
        if let startIndex = photos.firstIndex(where: { $0.id == initialPhoto.id }) {
            _currentIndex = State(initialValue: startIndex)
        }
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(photos.indices, id: \.self) { index in
                FullScreenPhotoView(photo: photos[index], photoManager: photoManager) {
                    // Propagate dismiss back to the parent when the user closes any page.
                    onDismiss()
                }
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        // Ensure the gallery itself obeys the same appearance rules as the underlying pages.
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .statusBarHidden()
        .onAppear {
            prefetchAround(index: currentIndex)
        }
        // Prefetch neighbouring photos when the user swipes to a new index. We deliberately avoid updating
        // `fullScreenPhotoManager.selectedPhoto` here to prevent SwiftUI from re-presenting the full-screen cover
        // on every page change, which caused the noticeable "bounce" / opening animation after each swipe.
        .onChange(of: currentIndex) { _, newValue in
            prefetchAround(index: newValue)
        }
    }

    private func prefetchAround(index: Int) {
        let neighbours = [index - 1, index + 1]
            .filter { $0 >= 0 && $0 < photos.count }
            .map { photos[$0] }
        FullScreenPhotoView.prefetch(neighbours)
    }

    // Environment object previously used to sync the selected photo back to callers. Now unused but kept here in case
    // future features need it again. Commented out to silence compiler warnings.
    // @EnvironmentObject private var fullScreenPhotoManager: FullScreenPhotoManager
}

#Preview {
    // Mock data for preview
    let manager = PhotoManager()
    let samplePhotos: [Photo] = [
        Photo(asset: PHAsset(), dateAdded: Date()),
        Photo(asset: PHAsset(), dateAdded: Date()),
        Photo(asset: PHAsset(), dateAdded: Date())
    ]
    FullScreenPhotoGalleryView(photos: samplePhotos, initialPhoto: samplePhotos[0], photoManager: manager) {}
        // .environmentObject(FullScreenPhotoManager())
}
