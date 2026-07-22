import UIKit
import AudioToolbox

/// Haptic + sound cue fired each time a word is scored.
enum FeedbackPlayer {
    private static let generator = UIImpactFeedbackGenerator(style: .medium)

    // A short built-in system sound stands in for a custom "ding" asset —
    // avoids bundling/licensing an audio file for this v1 draft.
    private static let scoreSoundID: SystemSoundID = 1057

    static func wordScored() {
        generator.impactOccurred()
        AudioServicesPlaySystemSound(scoreSoundID)
    }
}
