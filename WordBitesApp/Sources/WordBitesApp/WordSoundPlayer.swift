import AVFoundation

/// Plays a short chime when a word is scored, pitched low for short words
/// and higher (and slightly longer) for long ones. Each call spins up its
/// own `AVAudioPlayer` from cached audio data rather than reusing one
/// shared player, so words scored in quick succession layer on top of each
/// other cleanly instead of cutting each other off.
final class WordSoundPlayer: NSObject {
    static let shared = WordSoundPlayer()

    private var soundURLs: [Int: URL] = [:]
    private var activePlayers: [AVAudioPlayer] = []

    private override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        for length in 3...6 {
            soundURLs[length] = Bundle.main.url(forResource: "WordSound\(length)", withExtension: "wav")
        }
    }

    /// Returns a short diagnostic tag describing what happened, temporarily
    /// surfaced on-screen while tracking down why these sounds go unheard
    /// on-device despite the resources and audio session checking out.
    @discardableResult
    func play(length: Int) -> String {
        let tier = min(max(length, 3), 6)
        guard let url = soundURLs[tier] else { return "no-url" }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return "init-failed" }
        player.delegate = self
        player.volume = 1.0
        activePlayers.append(player)
        let prepared = player.prepareToPlay()
        let started = player.play()
        return "ok dur=\(String(format: "%.2f", player.duration)) prep=\(prepared) play=\(started) vol=\(player.volume) route=\(AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ","))"
    }
}

extension WordSoundPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activePlayers.removeAll { $0 === player }
    }
}
