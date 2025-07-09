import SwiftUI
import Photos

struct TrashView: View {
    @ObservedObject var photoManager: PhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearAlert = false
    @State private var selectedPhoto: Photo?
    @State private var showingFullScreen = false
    
    private let columns = Array(repeating: GridItem(.flexible()), count: UIDevice.current.userInterfaceIdiom == .pad ? 4 : 3)
    
    var body: some View {
        NavigationView {
            VStack {
                if photoManager.trashedPhotos.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "trash")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 60))
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        
                        Text("Корзина пуста")
                            .font(UIDevice.current.userInterfaceIdiom == .pad ? .title : .title2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        
                        Text("Удаленные фото будут появляться здесь")
                            .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .body)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Photo grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 12) {
                            ForEach(photoManager.trashedPhotos) { photo in
                                TrashPhotoCard(
                                    photo: photo,
                                    photoManager: photoManager,
                                    onRestore: { restorePhoto(photo) },
                                    onTap: { showFullScreen(for: photo) }
                                )
                            }
                        }
                        .padding()
                    }
                    .constrainedToDevice(usePadding: false)
                }
            }
            .navigationTitle("Корзина (\(photoManager.trashedPhotos.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Отмена")
                        }
                        .adaptiveFont(.body)
                    }
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingClearAlert = true }) {
                        HStack(spacing: 4) {
                            Text("Очистить")
                            Image(systemName: "trash")
                        }
                        .adaptiveFont(.body)
                    }
                    .foregroundColor(photoManager.trashedPhotos.isEmpty ? AppColors.secondaryText(for: themeManager.isDarkMode) : .red)
                    .disabled(photoManager.trashedPhotos.isEmpty)
                }
            }
            .alert("Очистить корзину", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить все", role: .destructive) {
                    withAnimation(.spring()) { 
                        photoManager.clearAllTrash() 
                    }
                }
            } message: {
                Text("Вы уверены, что хотите удалить все фото из корзины? Это действие нельзя отменить.")
            }
            .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
        }
        .overlay {
            if showingFullScreen, let photo = selectedPhoto {
                FullScreenPhotoView(photo: photo, photoManager: photoManager) {
                    withAnimation(AppAnimations.modal) {
                        showingFullScreen = false
                        selectedPhoto = nil
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }
    
    // MARK: - Actions
    private func restorePhoto(_ photo: Photo) {
        withAnimation(.spring()) {
            photoManager.restoreFromTrash(photo)
        }
    }
    
    private func showFullScreen(for photo: Photo) {
        withAnimation(AppAnimations.modal) {
            selectedPhoto = photo
            showingFullScreen = true
        }
    }
}

struct TrashPhotoCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let photo: Photo
    let photoManager: PhotoManager
    let onRestore: () -> Void
    let onTap: () -> Void
    @State private var isPressed = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                PhotoImageView(
                    photo: photo,
                    targetSize: CGSize(width: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 100, 
                                     height: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 100)
                )
                .clipShape(RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12))
                .onTapGesture {
                    onTap()
                }
                
                // Restore button overlay
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onRestore) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(UIDevice.current.userInterfaceIdiom == .pad ? .title : .title2)
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.8)))
                        }
                    }
                    Spacer()
                }
                .padding(UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8)
            }
            
            Text(dateFormatter.string(from: photo.dateMovedToTrash ?? photo.dateAdded))
                .font(UIDevice.current.userInterfaceIdiom == .pad ? .caption : .caption2)
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) { 
            // Visual feedback only
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

#Preview {
    TrashView(photoManager: PhotoManager())
}
