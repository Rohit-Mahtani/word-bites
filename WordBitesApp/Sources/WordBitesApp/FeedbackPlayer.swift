import UIKit

/// Haptic + sound cues for scoring and tile movement. Score pitch rises
/// with word length; 6-7 letter words share a tier, as do 8-9 (the
/// longest a straight line on the board can hold).
enum FeedbackPlayer {
    private static let scoreHaptic = UIImpactFeedbackGenerator(style: .medium)
    private static let pickupHaptic = UIImpactFeedbackGenerator(style: .light)

    static func wordScored(length: Int) {
        scoreHaptic.impactOccurred()
        ToneEngine.shared.playDing(frequency: pitch(forLength: length), duration: 0.28)
    }

    static func tilePickedUp() {
        pickupHaptic.impactOccurred()
        ToneEngine.shared.playKnock(frequency: 260, duration: 0.05)
    }

    static func tilePlaced() {
        ToneEngine.shared.playKnock(frequency: 340, duration: 0.04)
    }

    private static func pitch(forLength length: Int) -> Double {
        switch length {
        case ..<4: return 587.33  // 3 letters — D5
        case 4: return 659.25     // E5
        case 5: return 783.99     // G5
        case 6, 7: return 987.77  // B5
        default: return 1318.51   // 8-9 letters — E6
        }
    }
}
