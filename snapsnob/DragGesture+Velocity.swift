import SwiftUI

extension DragGesture.Value {
    /// Approximate gesture velocity in points by using the difference between
    /// the predicted end location and the current location. While not perfect
    /// (SwiftUI does not expose raw velocity), this offers a reasonable estimate
    /// that can be used for threshold‐based interactions such as swipe-to-dismiss.
    var velocity: CGSize {
        CGSize(
            width: predictedEndLocation.x - location.x,
            height: predictedEndLocation.y - location.y
        )
    }
} 