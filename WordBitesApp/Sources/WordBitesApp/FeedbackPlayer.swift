import SwiftUI
import UIKit

/// Haptic and audio cues for scoring, tile movement, and button taps.
enum FeedbackPlayer {
    private static let scoreHaptic = UIImpactFeedbackGenerator(style: .medium)
    private static let pickupHaptic = UIImpactFeedbackGenerator(style: .light)
    private static let tapHaptic = UIImpactFeedbackGenerator(style: .light)

    static func wordScored(length: Int) {
        scoreHaptic.impactOccurred()
        let tier = min(max(length, 3), 6)
        SoundEffectPlayer.shared.play(resource: "WordSound\(tier)")
    }

    static func tilePickedUp() {
        pickupHaptic.impactOccurred()
        SoundEffectPlayer.shared.play(resource: "TilePickup")
    }

    static func tilePlaced() {
        pickupHaptic.impactOccurred()
        SoundEffectPlayer.shared.play(resource: "TileDrop")
    }

    static func buttonTapped() {
        tapHaptic.impactOccurred()
        SoundEffectPlayer.shared.play(resource: "ButtonTap")
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
