import SwiftUI

/// A lightweight view-modifier that constrains the content width when the app
/// runs on iPad, while leaving the iPhone layout untouched.
struct ConstrainedWidthModifier: ViewModifier {
    /// Desired maximum width. You can think of this as an *upper* bound – the
    /// final width is the **smaller** of 90 % of the current screen width and
    /// the value supplied here so that the UI scales nicely on every iPad
    /// size without becoming overly stretched. 
    let maxWidth: CGFloat
    let usePadding: Bool

    func body(content: Content) -> some View {
        // Apply the constraint only for iPad devices. On iPhone we forward the
        // original view hierarchy unchanged so that no additional work is done
        // by SwiftUI.
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Calculate an adaptive width that fills up to the screen width
            // while never exceeding the passed `maxWidth`. This approach keeps
            // the layout visually balanced on all current iPad sizes.
            let screenWidth = UIScreen.main.bounds.width
            let effectiveWidth = min(screenWidth * 0.95, maxWidth)

            if usePadding {
                content
                    // First limit the width of the content itself.
                    .frame(maxWidth: effectiveWidth, alignment: .center)
                    // Then expand the parent frame so the view stays centred inside
                    // the full available width.
                    .frame(maxWidth: .infinity)
            } else {
                // For full-width layouts, don't constrain
                content
                    .frame(maxWidth: .infinity)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Constrains the view's width on iPad to the supplied value. For iPhone
    /// devices the modifier does nothing so existing layouts continue to work
    /// as before.
    ///
    /// Usage:
    /// ```swift
    /// ScrollView {
    ///     // …
    /// }
    /// .constrainedToDevice() // Uses the default max width
    /// ```
    ///
    /// - Parameter maxWidth: Desired maximum width on iPad. Default is `1200`.
    /// - Parameter usePadding: Whether to apply width constraints. Default is `true`.
    /// - Returns: A view whose width is limited on iPad.
    func constrainedToDevice(maxWidth: CGFloat = 1200, usePadding: Bool = true) -> some View {
        self.modifier(ConstrainedWidthModifier(maxWidth: maxWidth, usePadding: usePadding))
    }
} 