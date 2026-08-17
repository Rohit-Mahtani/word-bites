import AVFoundation

/// Loops the app's background music continuously from launch. Uses the
/// `.ambient` audio session category so it respects the device's silent
/// switch and yields to other audio, like any casual game's background
/// music should.
enum MusicPlayer {
    private static var player: AVAudioPlayer?

    /// Creates and, if the player is on, starts the looping player. Always
    /// creates the `AVAudioPlayer` regardless of the current on/off setting
    /// -- so a later `setEnabled(true)` from the welcome screen's toggle can
    /// just resume the same instance (preserving loop position) instead of
    /// re-decoding the file from scratch.
    static func start() {
        guard player == nil else { return }
        guard let url = Bundle.main.url(forResource: "BackgroundMusic", withExtension: "mp3") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.numberOfLoops = -1
            audioPlayer.volume = 0.5
            audioPlayer.prepareToPlay()
            player = audioPlayer
            if AudioSettings.isMusicEnabled {
                audioPlayer.play(atTime: audioPlayer.deviceCurrentTime + 0.5)
            }
        } catch {
            // Background music failing to load/play should never block gameplay.
        }
    }

    /// Called from the welcome screen's music toggle. Persists the setting
    /// and pauses/resumes the already-created player in place.
    static func setEnabled(_ enabled: Bool) {
        AudioSettings.isMusicEnabled = enabled
        guard let player else { return }
        if enabled {
            player.play()
        } else {
            player.pause()
        }
    }
}
