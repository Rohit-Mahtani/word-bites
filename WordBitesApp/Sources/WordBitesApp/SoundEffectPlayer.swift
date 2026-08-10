import AVFoundation

/// Plays short one-shot sound effects (word-scored chimes, tile pickup/drop,
/// button taps) by name. Each call spins up its own `AVAudioPlayer` rather
/// than reusing one shared player, so sounds triggered in quick succession
/// layer on top of each other instead of cutting off.
final class SoundEffectPlayer: NSObject {
    static let shared = SoundEffectPlayer()

    private var activePlayers: [AVAudioPlayer] = []

    // Every resource's raw bytes, read from disk once up front instead of
    // on every play() call. tilePickedUp()/tilePlaced() are called directly
    // from inside the drag gesture's onChanged/onEnded closures -- the same
    // runloop turn that moves the tile -- so `AVAudioPlayer(contentsOf:)`'s
    // disk read there was a real, synchronous main-thread hitch landing at
    // the exact moment of every pickup and drop, not just a one-off cost.
    // Constructing a player from already-in-memory Data still does real
    // work (decoding) but skips the disk I/O, which is the part with
    // unpredictable latency.
    private var cachedData: [String: Data] = [:]

    private override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        for resource in [
            "WordSound3", "WordSound4", "WordSound5", "WordSound6",
            "TilePickup", "TileDrop", "ButtonTap"
        ] {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "wav"),
                  let data = try? Data(contentsOf: url) else { continue }
            cachedData[resource] = data
        }
    }

    /// Silently does nothing if the named resource isn't bundled/cached, or
    /// if the player has sound effects turned off, so callers don't need to
    /// guard either case themselves.
    func play(resource: String, extension ext: String = "wav") {
        guard AudioSettings.isSFXEnabled else { return }
        guard let data = cachedData[resource],
              let player = try? AVAudioPlayer(data: data) else { return }
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
