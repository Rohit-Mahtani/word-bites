import SwiftUI
import UIKit

/// Haptic and audio cues for scoring, tile movement, and button taps.
enum FeedbackPlayer {
    private static let scoreHaptic = UIImpactFeedbackGenerator(style: .medium)
    private static let pickupHaptic = UIImpactFeedbackGenerator(style: .light)
    private static let tapHaptic = UIImpactFeedbackGenerator(style: .light)

    @discardableResult
    static func wordScored(length: Int) -> String {
        scoreHaptic.impactOccurred()
        return WordSoundPlayer.shared.play(length: length)
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
