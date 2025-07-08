import Foundation
import AudioToolbox
import UIKit

/// Centralised utility for lightweight auditory & haptic feedback that feels native
/// to the Apple Human-Interface-Guidelines experience.
/// The helper is intentionally simple – the built-in keyboard "click" keeps the
/// binary size minimal while still delivering a delightful dopamine trigger.
struct SoundManager {
    /// Plays a soft "click" sound together with a light impact haptic.
    /// The call is non-blocking and safe to trigger from the main thread.
    static func playClick() {
        // System sound ID 1104 is the default keyboard tap.
        AudioServicesPlaySystemSound(1104)
        // Haptic feedback – mirrors the subtle feedback in Apple Photos.
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
} 