import SwiftUI

/// A lightweight view-modifier that optimizes layout for different device types.
/// On iPhone, it preserves the original layout. On iPad, it provides proper
/// edge-to-edge layout with appropriate padding for 13-inch displays.
struct ConstrainedWidthModifier: ViewModifier {
    /// Whether to add horizontal padding on iPad
    let usePadding: Bool
    
    /// Base padding for iPad layouts
    private var iPadPadding: CGFloat {
        // Adaptive padding based on screen size
        let screenWidth = UIScreen.main.bounds.width
        if screenWidth > 1024 { // iPad Pro 12.9/13"
            return 40
        } else if screenWidth > 834 { // iPad Pro 11"
            return 30
        } else { // Regular iPad
            return 20
        }
    }

    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // On iPad, apply edge-to-edge layout with proper padding
            content
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, usePadding ? iPadPadding : 0)
        } else {
            // On iPhone, preserve original layout
            content
        }
    }
}

extension View {
    /// Optimizes the view's layout for the current device.
    /// On iPhone: No changes are made to preserve existing layout.
    /// On iPad: Expands content to full width with appropriate padding.
    ///
    /// Usage:
    /// ```swift
    /// ScrollView {
    ///     // content
    /// }
    /// .constrainedToDevice() // Adds padding on iPad
    /// .constrainedToDevice(usePadding: false) // No padding, full edge-to-edge
    /// ```
    ///
    /// - Parameter usePadding: Whether to apply horizontal padding on iPad. Default is `true`.
    /// - Returns: A view optimized for the current device.
    func constrainedToDevice(usePadding: Bool = true) -> some View {
        self.modifier(ConstrainedWidthModifier(usePadding: usePadding))
    }
} 