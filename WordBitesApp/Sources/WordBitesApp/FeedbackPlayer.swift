import UIKit

/// Haptic cues for scoring and tile movement. Sound effects were removed —
/// custom audio is coming later.
enum FeedbackPlayer {
    private static let scoreHaptic = UIImpactFeedbackGenerator(style: .medium)
    private static let pickupHaptic = UIImpactFeedbackGenerator(style: .light)

    static func wordScored(length: Int) {
        scoreHaptic.impactOccurred()
    }

    static func tilePickedUp() {
        pickupHaptic.impactOccurred()
    }

    static func tilePlaced() {
        pickupHaptic.impactOccurred()
    }
}
