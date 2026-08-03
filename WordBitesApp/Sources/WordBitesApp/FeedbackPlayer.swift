import SwiftUI
import UIKit

/// Haptic cues for scoring, tile movement, and button taps. Sound effects
/// were removed — custom audio is coming later.
enum FeedbackPlayer {
    private static let scoreHaptic = UIImpactFeedbackGenerator(style: .medium)
    private static let pickupHaptic = UIImpactFeedbackGenerator(style: .light)
    private static let tapHaptic = UIImpactFeedbackGenerator(style: .light)

    static func wordScored(length: Int) {
        scoreHaptic.impactOccurred()
    }

    static func tilePickedUp() {
        pickupHaptic.impactOccurred()
    }

    static func tilePlaced() {
        pickupHaptic.impactOccurred()
    }

    static func buttonTapped() {
        tapHaptic.impactOccurred()
    }
}

/// Applied once at the app root so every `Button` anywhere in the app gets
/// a light haptic on press, without touching each button's own call site.
/// Non-`Button` tap targets (e.g. `ModeSelectView`'s `SegmentedPill`, which
/// uses `onTapGesture`) call `FeedbackPlayer.buttonTapped()` directly since
/// they fall outside SwiftUI's `ButtonStyle` system.
struct HapticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    FeedbackPlayer.buttonTapped()
                }
            }
    }
}
