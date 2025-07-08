import SwiftUI

// MARK: - Common UI Components
/// This file contains reusable UI components used throughout the SnapSnob app.
/// Components are organized to promote reusability and maintain consistent UI patterns.

// MARK: - Button Styles

/// A circular button style with transparent background and glass effect
/// Used for action buttons (trash, favorite, keep) in photo cards
struct TransparentCircleButtonStyle: ButtonStyle {
    @EnvironmentObject var themeManager: ThemeManager
    /// Size of the circular button
    var size: CGFloat = 56
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            )
            // Smoother interactive spring & subtle scale
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
            // Soft glow visible only on press
            .shadow(color: AppColors.primaryText(for: themeManager.isDarkMode).opacity(configuration.isPressed ? 0.4 : 0.0),
                    radius: configuration.isPressed ? 6 : 0)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.65, blendDuration: 0.25), value: configuration.isPressed)
    }
}

// MARK: - Story Components

/// A circular story thumbnail component with viewing state and favorite indicator
struct StoryCircle: View {
    @EnvironmentObject var themeManager: ThemeManager
    let series: PhotoSeriesData
    let photoManager: PhotoManager
    let isViewed: Bool
    let onTap: () -> Void
    
    /// Whether series contains at least one favourite photo
    private var hasFavourite: Bool {
        series.photos.contains { $0.isFavorite }
    }
    
    /// Responsive sizing for different device types
    private var circleSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 95 : 75
    }
    
    private var frameWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 100 : 78
    }
    
    var body: some View {
        VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 8 : 4) {
            Button(action: onTap) {
                // Photo fills entire outer frame with stroke overlay
                PhotoImageView(
                    photo: series.thumbnailPhoto,
                    targetSize: CGSize(width: circleSize, height: circleSize)
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            isViewed ? AppColors.secondaryText(for: themeManager.isDarkMode).opacity(0.2) : AppColors.accent(for: themeManager.isDarkMode),
                            lineWidth: UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
                        )
                )
                .shadow(color: isViewed ? .clear : .purple.opacity(0.3), radius: UIDevice.current.userInterfaceIdiom == .pad ? 8 : 6, x: 0, y: 2)
                .overlay(
                    Group {
                        if hasFavourite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.white)
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12))
                                .background(Circle().fill(Color.white).frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18,
                                                                           height: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18))
                                .clipShape(Circle())
                                .offset(x: UIDevice.current.userInterfaceIdiom == .pad ? 30 : 24, 
                                       y: UIDevice.current.userInterfaceIdiom == .pad ? 30 : 24)
                        }
                    }
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isViewed ? 0.95 : 1.0)
            
            Text(series.title)
                .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                .fontWeight(.medium)
                .foregroundColor(isViewed ? AppColors.secondaryText(for: themeManager.isDarkMode) : AppColors.primaryText(for: themeManager.isDarkMode))
                .lineLimit(1)
                .frame(width: frameWidth)
        }
    }
}

// MARK: - Photo Display Components

/// An optimized photo view that handles image loading and caching efficiently
/// This is a wrapper around PhotoImageView with enhanced preloading support
struct OptimizedPhotoView: View {
    let photo: Photo
    let targetSize: CGSize
    
    var body: some View {
        PhotoImageView(
            photo: photo,
            targetSize: targetSize
        )
        // Trigger immediate loading for preloaded images
        .onAppear {
            // The PhotoImageView will handle the actual loading
            // This ensures immediate loading when the view appears
        }
    }
}

// MARK: - Card Components

/// A standardized card component with consistent styling
struct StandardCard<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let cornerRadius: CGFloat
    let content: () -> Content
    
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }
    
    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.border(for: themeManager.isDarkMode), lineWidth: 1)
            )
            .shadow(color: AppColors.shadow(for: themeManager.isDarkMode), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Stat Badge Components

/// A small badge showing statistics with icon
struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Gradient Button Style

/// A button style with gradient background
struct GradientButtonStyle: ButtonStyle {
    let colors: [Color]
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    
    init(
        colors: [Color] = [.blue, .purple],
        cornerRadius: CGFloat = 16,
        horizontalPadding: CGFloat = 24,
        verticalPadding: CGFloat = 16
    ) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Loading Overlay

/// A standardized loading overlay component
struct LoadingOverlay: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.body)
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
        )
        .shadow(radius: 10)
    }
}

// MARK: - Empty State View

/// A reusable empty state view component
struct EmptyStateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        icon: String,
        title: String,
        message: String,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                
                Text(message)
                    .font(.body)
                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                    .multilineTextAlignment(.center)
            }
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .buttonStyle(GradientButtonStyle())
            }
        }
        .padding(40)
    }
} 