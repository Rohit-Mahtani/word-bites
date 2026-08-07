import AVFoundation

/// Plays a short chime when a word is scored, pitched low for short words
/// and higher (and slightly longer) for long ones. Each call spins up its
/// own `AVAudioPlayer` from cached audio data rather than reusing one
/// shared player, so words scored in quick succession layer on top of each
/// other cleanly instead of cutting each other off.
final class WordSoundPlayer: NSObject {
    static let shared = WordSoundPlayer()

    private var soundData: [Int: Data] = [:]
    private var activePlayers: [AVAudioPlayer] = []

    private override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        for length in 3...6 {
            guard let url = Bundle.main.url(forResource: "WordSound\(length)", withExtension: "wav"),
                  let data = try? Data(contentsOf: url) else { continue }
            soundData[length] = data
        }
    }

    func play(length: Int) {
        let tier = min(max(length, 3), 6)
        guard let data = soundData[tier], let player = try? AVAudioPlayer(data: data) else { return }
        player.delegate = self
        activePlayers.append(player)
        player.prepareToPlay()
        player.play()
    }
}

extension WordSoundPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activePlayers.removeAll { $0 === player }
    }
}
