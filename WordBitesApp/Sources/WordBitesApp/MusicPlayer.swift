import AVFoundation

/// Loops the app's background music continuously from launch. Uses the
/// `.ambient` audio session category so it respects the device's silent
/// switch and yields to other audio, like any casual game's background
/// music should.
enum MusicPlayer {
    private static var player: AVAudioPlayer?

    static func start() {
        guard player == nil else { return }
        guard let url = Bundle.main.url(forResource: "BackgroundMusic", withExtension: "mp3") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.numberOfLoops = -1
            audioPlayer.volume = 0.4
            audioPlayer.prepareToPlay()
            audioPlayer.play(atTime: audioPlayer.deviceCurrentTime + 0.5)
            player = audioPlayer
        } catch {
            // Background music failing to load/play should never block gameplay.
        }
    }
}
