import SwiftUI

struct AppAnimations {
    /// Unified modal / sheet animation used across the app
    static let modal: Animation = .easeInOut(duration: 0.3)

    /// Primary animation for card swipe / dismiss actions – tuned for smooth, чёткий выход без лишнего отскока
    /// Используем easeOut-кривую, чтобы карточка стабильно уходила за экран и не дёргалась в конце.
    static let cardSwipe: Animation = .interactiveSpring(response: 0.40, dampingFraction: 0.85, blendDuration: 0.25)

    /// Entrance animation for the next card appearing on screen
    static let cardEntrance: Animation = .interactiveSpring(response: 0.50, dampingFraction: 0.90, blendDuration: 0.25)

    /// Reset animation when the drag is cancelled and the card returns to center
    static let cardReset: Animation = .interactiveSpring(response: 0.45, dampingFraction: 0.88, blendDuration: 0.25)

    /// Bounce animation for small UI elements (e.g., trash icon highlight)
    static let iconBounce: Animation = .spring(response: 0.35, dampingFraction: 0.7)
} 