import SwiftUI

/// A photo grid that supports swipe gestures on individual photos.
/// Swipe left: remove from favorites
/// Swipe right: mark as super star
struct SwipeablePhotoGrid: View {
    let photos: [Photo]
    let photoManager: PhotoManager
    let onPhotoTap: (Photo) -> Void
    
    // Grid configuration
    private let columns = Array(repeating: GridItem(.flexible()), count: 3)
    private let spacing: CGFloat = 12
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(photos) { photo in
                    SwipeablePhotoCell(
                        photo: photo,
                        photoManager: photoManager,
                        onTap: { onPhotoTap(photo) }
                    )
                }
            }
            .padding(spacing)
        }
    }
}

// MARK: - Swipeable Photo Cell
private struct SwipeablePhotoCell: View {
    @EnvironmentObject var themeManager: ThemeManager
    let photo: Photo
    let photoManager: PhotoManager
    let onTap: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isProcessingAction = false
    @State private var showingActionFeedback = false
    @State private var actionType: ActionType = .none
    
    private enum ActionType {
        case none, removeFavorite, addSuperStar
    }
    
    var body: some View {
        ZStack {
            // Background action indicators
            HStack {
                // Left side - Remove from favorites
                if dragOffset.width < -20 {
                    HStack {
                        Image(systemName: "heart.slash.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .opacity(min(Double(abs(dragOffset.width)) / 60.0, 1.0))
                }
                
                Spacer()
                
                // Right side - Add super star
                if dragOffset.width > 20 {
                    HStack {
                        Spacer()
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 8)
                    .opacity(min(Double(dragOffset.width) / 60.0, 1.0))
                }
            }
            
            // Photo cell
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    PhotoImageView(
                        photo: photo,
                        targetSize: CGSize(width: 100, height: 100)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Super star badge
                    if photo.isSuperStar {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.6))
                            )
                            .padding(4)
                    }
                }
                
                // Heart button for favorites
                Button(action: {
                    photoManager.setFavorite(photo, isFavorite: false)
                }) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                        .font(.caption2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .offset(dragOffset)
            .scaleEffect(isProcessingAction ? 0.95 : 1.0)
            .opacity(isProcessingAction ? 0.8 : 1.0)
            .onTapGesture {
                if !isProcessingAction {
                    onTap()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isProcessingAction {
                            dragOffset = value.translation
                            
                            // Determine action type based on drag direction
                            if value.translation.width < -40 {
                                actionType = .removeFavorite
                            } else if value.translation.width > 40 {
                                actionType = .addSuperStar
                            } else {
                                actionType = .none
                            }
                        }
                    }
                    .onEnded { value in
                        if !isProcessingAction {
                            handleDragEnd(value: value)
                        }
                    }
            )
            
            // Action feedback overlay
            if showingActionFeedback {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.7))
                    .overlay(
                        VStack {
                            Image(systemName: actionType == .addSuperStar ? "star.fill" : "heart.slash.fill")
                                .foregroundColor(actionType == .addSuperStar ? .yellow : .red)
                                .font(.system(size: 24))
                            
                            Text(actionType == .addSuperStar ? "Super Star!" : "Removed")
                                .foregroundColor(.white)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    )
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: dragOffset)
        .animation(.easeInOut(duration: 0.2), value: isProcessingAction)
    }
    
    private func handleDragEnd(value: DragGesture.Value) {
        let threshold: CGFloat = 60
        let translation = value.translation
        
        if translation.width < -threshold {
            // Remove from favorites
            performAction(.removeFavorite)
        } else if translation.width > threshold {
            // Add super star
            performAction(.addSuperStar)
        } else {
            // Reset position
            withAnimation(AppAnimations.cardReset) {
                dragOffset = .zero
                actionType = .none
            }
        }
    }
    
    private func performAction(_ action: ActionType) {
        isProcessingAction = true
        actionType = action
        showingActionFeedback = true
        
        // Animate to completion
        let targetOffset: CGSize
        switch action {
        case .removeFavorite:
            targetOffset = CGSize(width: -120, height: 0)
            photoManager.setFavorite(photo, isFavorite: false)
        case .addSuperStar:
            targetOffset = CGSize(width: 120, height: 0)
            photoManager.setSuperStar(photo, isSuperStar: true)
        case .none:
            targetOffset = .zero
        }
        
        withAnimation(AppAnimations.cardSwipe) {
            dragOffset = targetOffset
        }
        
        // Hide feedback and reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingActionFeedback = false
                dragOffset = .zero
                isProcessingAction = false
                actionType = .none
            }
        }
    }
}

#Preview {
    let photoManager = PhotoManager()
    SwipeablePhotoGrid(photos: [], photoManager: photoManager) { _ in }
} 