import SwiftUI

/// A lightweight view-modifier that constrains the content width when the app
/// runs on iPad, while leaving the iPhone layout untouched.
struct ConstrainedWidthModifier: ViewModifier {
    /// The maximum width the content is allowed to take on iPad.
    /// Defaults to 640 pt which visually matches the iPhone design on larger
    /// screens without making the interface look overly stretched.
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        // Apply the constraint only for iPad devices. On iPhone we forward the
        // original view hierarchy unchanged so that no additional work is done
        // by SwiftUI.
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                // First limit the width of the content itself.
                .frame(maxWidth: maxWidth, alignment: .center)
                // Then expand the parent frame so the view stays centred inside
                // the full available width.
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// Constrains the view’s width on iPad to the supplied value. For iPhone
    /// devices the modifier does nothing so existing layouts continue to work
    /// as before.
    ///
    /// Usage:
    /// ```swift
    /// ScrollView {
    ///     // …
    /// }
    /// .constrainedToDevice() // Uses the default 640-pt max width
    /// ```
    ///
    /// - Parameter maxWidth: Desired maximum width on iPad. Default is `640`.
    /// - Returns: A view whose width is limited on iPad.
    func constrainedToDevice(maxWidth: CGFloat = 640) -> some View {
        self.modifier(ConstrainedWidthModifier(maxWidth: maxWidth))
    }
} 