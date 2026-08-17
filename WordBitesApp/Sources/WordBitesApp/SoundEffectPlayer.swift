import AVFoundation

/// Plays short one-shot sound effects (word-scored chimes, tile pickup/drop,
/// button taps) by name.
///
/// Built on `AVAudioEngine` + a small pool of pre-connected
/// `AVAudioPlayerNode`s per sound, instead of constructing a fresh
/// `AVAudioPlayer` on every call. The previous approach measurably caused
/// the gameplay choppiness itself (confirmed by the user: muting sound
/// effects alone made dragging perfectly smooth) -- every pickup, drop, and
/// scored word was allocating a brand-new `AVAudioPlayer` (WAV parsing,
/// buffer allocation, a new CoreAudio graph node) via
/// `DispatchQueue.global(qos: .userInteractive)`, which is the *same*
/// scheduling tier the main thread's own UI/gesture work runs at -- so it
/// was never actually independent of gameplay, just dispatched elsewhere.
///
/// Here, every sound's PCM data is decoded once at setup, and each play
/// call just schedules that already-decoded buffer onto an already-running,
/// already-connected node -- no allocation, no parsing, no engine
/// reconfiguration on the hot path. All engine setup and every trigger runs
/// on one dedicated serial queue at `.userInitiated` (not `.userInteractive`),
/// so this queue is never competing with the main thread at its own
/// priority tier.
final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()

    private let engine = AVAudioEngine()

    // Each resource gets a handful of player nodes, cycled round-robin, so
    // the same sound triggered rapidly (e.g. several 3-letter words scored
    // back to back) still layers/overlaps the way distinct AVAudioPlayer
    // instances used to, rather than a single node cutting itself off.
    private struct VoicePool {
        let nodes: [AVAudioPlayerNode]
        let buffer: AVAudioPCMBuffer
        var nextIndex = 0
    }
    private static let voicesPerResource = 4

    private var pools: [String: VoicePool] = [:]
    private let queue = DispatchQueue(label: "com.rohitmahtani.wordbites.audio", qos: .userInitiated)

    private init() {
        queue.async { [weak self] in
            self?.setUpEngine()
        }
    }

    private func setUpEngine() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        for resource in ["WordSound3", "WordSound4", "WordSound5", "WordSound6", "TilePickup", "TileDrop", "ButtonTap"] {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "wav"),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil
            else { continue }

            let nodes = (0..<Self.voicesPerResource).map { _ in AVAudioPlayerNode() }
            for node in nodes {
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
            }
            pools[resource] = VoicePool(nodes: nodes, buffer: buffer)
        }

        try? engine.start()
    }

    /// Silently does nothing if the named resource isn't ready yet, or if
    /// the player has sound effects turned off, so callers don't need to
    /// guard either case themselves.
    func play(resource: String) {
        guard AudioSettings.isSFXEnabled else { return }
        queue.async { [weak self] in
            guard let self, var pool = self.pools[resource] else { return }

            if !self.engine.isRunning {
                // The engine can stop itself on a real audio interruption
                // (a phone call, Siri, another app taking audio focus) --
                // restart it defensively so sound doesn't silently die for
                // the rest of the session.
                try? self.engine.start()
            }

            let node = pool.nodes[pool.nextIndex]
            pool.nextIndex = (pool.nextIndex + 1) % pool.nodes.count
            self.pools[resource] = pool

            node.stop()
            node.scheduleBuffer(pool.buffer, at: nil, options: [])
            node.play()
        }
    }
}
