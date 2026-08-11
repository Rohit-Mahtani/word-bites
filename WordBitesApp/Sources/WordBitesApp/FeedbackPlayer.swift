import SwiftUI
import UIKit

/// Haptic and audio cues for scoring, tile movement, and button taps.
enum FeedbackPlayer {
    private static let scoreHaptic = UIImpactFeedbackGenerator(style: .medium)
    private static let pickupHaptic = UIImpactFeedbackGenerator(style: .light)
    private static let tapHaptic = UIImpactFeedbackGenerator(style: .light)

    /// Warms up the Taptic Engine ahead of the first real trigger --
    /// Apple's own guidance is that `prepare()` shortly before an expected
    /// `impactOccurred()` reduces that call's latency. Called once when the
    /// game screen appears; each trigger below re-prepares itself
    /// afterward so the generator stays warm for the next one too.
    static func prepareAll() {
        scoreHaptic.prepare()
        pickupHaptic.prepare()
        tapHaptic.prepare()
    }

    static func wordScored(length: Int) {
        scoreHaptic.impactOccurred()
        scoreHaptic.prepare()
        let tier = min(max(length, 3), 6)
        SoundEffectPlayer.shared.play(resource: "WordSound\(tier)")
    }

    static func tilePickedUp() {
        pickupHaptic.impactOccurred()
        pickupHaptic.prepare()
        SoundEffectPlayer.shared.play(resource: "TilePickup")
    }

    static func tilePlaced() {
        pickupHaptic.impactOccurred()
        pickupHaptic.prepare()
        SoundEffectPlayer.shared.play(resource: "TileDrop")
    }

    static func buttonTapped() {
        tapHaptic.impactOccurred()
        tapHaptic.prepare()
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
