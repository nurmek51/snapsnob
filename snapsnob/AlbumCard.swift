import SwiftUI

struct AlbumCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let album: PhotoAlbum
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Cover image
                Group {
                    if let thumbnail = album.thumbnailPhoto {
                        PhotoImageView(photo: thumbnail, targetSize: CGSize(width: 180, height: 100))
                            .aspectRatio(1.8, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                            .overlay(
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            )
                            .aspectRatio(1.8, contentMode: .fill)
                    }
                }
                .clipShape(
                    .rect(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 16
                    )
                )

                VStack(spacing: 4) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                                .frame(width: 28, height: 28)
                            Image(systemName: "folder.fill")
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                .font(.system(size: 12, weight: .semibold))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                .lineLimit(1)
                            // Show count excluding trashed photos for accuracy
                            Text("\(album.photos.filter { !$0.isTrashed }.count) фото")
                                .font(.caption2)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                        .clipShape(
                            .rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 16,
                                bottomTrailingRadius: 16,
                                topTrailingRadius: 0
                            )
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) { } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

#Preview {
    AlbumCard(album: PhotoAlbum(title: "Preview", photos: [])) {}
} 