import SwiftUI
import UIKit

struct AlbumCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let album: PhotoAlbum
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            print("📁 Album tapped: \(album.title)")
            onTap()
        }) {
            VStack(spacing: 0) {
                // Cover image
                Group {
                    GeometryReader { geo in
                        if let thumbnail = album.thumbnailPhoto {
                            PhotoImageView(
                                photo: thumbnail,
                                // Request thumbnail at roughly on-screen pixel size
                                targetSize: CGSize(width: geo.size.width * UIScreen.main.scale,
                                                   height: geo.size.height * UIScreen.main.scale)
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                        } else {
                            Rectangle()
                                .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                                .overlay(
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title))
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                )
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                    // 16:9 aspect ratio (wider than tall) for a sleeker card look
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                }
                .clipShape(
                    .rect(
                        topLeadingRadius: DeviceInfo.shared.screenSize.cornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: DeviceInfo.shared.screenSize.cornerRadius
                    )
                )

                VStack(spacing: DeviceInfo.shared.spacing(0.3)) {
                    HStack(spacing: DeviceInfo.shared.spacing(0.6)) {
                        ZStack {
                            Circle()
                                .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                                .frame(width: DeviceInfo.shared.spacing(1.8), height: DeviceInfo.shared.spacing(1.8))
                            Image(systemName: "folder.fill")
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                                .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption * 1.2, weight: .semibold))
                        }

                        VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.1)) {
                            Text(album.title)
                                .adaptiveFont(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            // Show count excluding trashed photos for accuracy
                            Text("\(album.photos.filter { !$0.isTrashed }.count) фото")
                                .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption * 0.9))
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption * 0.9, weight: .medium))
                    }
                }
                .padding(DeviceInfo.shared.spacing(0.8))
                .background(
                    RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                        .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                        .clipShape(
                            .rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: DeviceInfo.shared.screenSize.cornerRadius,
                                bottomTrailingRadius: DeviceInfo.shared.screenSize.cornerRadius,
                                topTrailingRadius: 0
                            )
                        )
                )
            }
            // Limit the hit-testing region to the actual card bounds so it doesn’t overlap other UI.
            .contentShape(RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius))
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
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