import AVFoundation

/// Plays short one-shot sound effects (word-scored chimes, tile pickup/drop)
/// by name. Each call spins up its own `AVAudioPlayer` from the bundled
/// resource rather than reusing one shared player, so sounds triggered in
/// quick succession layer on top of each other instead of cutting off.
final class SoundEffectPlayer: NSObject {
    static let shared = SoundEffectPlayer()

    private var activePlayers: [AVAudioPlayer] = []

    private override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Silently does nothing if the named resource isn't bundled, so callers
    /// don't need to guard for sounds that haven't been added yet.
    func play(resource: String, extension ext: String = "wav") {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.delegate = self
        activePlayers.append(player)
        player.prepareToPlay()
        player.play()
    }
}

extension SoundEffectPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activePlayers.removeAll { $0 === player }
    }
}
