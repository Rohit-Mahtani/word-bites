import AVFoundation

/// Synthesizes short tones on the fly rather than bundling audio assets —
/// needed because the score ding has to vary pitch by word length, which a
/// fixed pre-recorded sound can't do.
final class ToneEngine {
    static let shared = ToneEngine()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100

    private init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
    }

    /// A pure tone with a quick attack and exponential decay — reads as a
    /// pleasant "ding" rather than a flat lab tone.
    func playDing(frequency: Double, duration: Double) {
        guard let buffer = makeBuffer(duration: duration, generator: { t in
            let envelope = t < 0.008 ? t / 0.008 : exp(-(t - 0.008) * 7.0)
            return sin(2.0 * .pi * frequency * t) * envelope
        }) else { return }
        schedule(buffer)
    }

    /// A short, low, noisy knock — stands in for a wooden tile tap.
    func playKnock(frequency: Double, duration: Double) {
        guard let buffer = makeBuffer(duration: duration, generator: { t in
            let envelope = exp(-t * 45.0)
            let tone = sin(2.0 * .pi * frequency * t)
            let noise = Double.random(in: -1...1)
            return (tone * 0.7 + noise * 0.3) * envelope
        }) else { return }
        schedule(buffer)
    }

    private func schedule(_ buffer: AVAudioPCMBuffer) {
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    private func makeBuffer(duration: Double, generator: (Double) -> Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard frameCount > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            channel[frame] = Float(generator(t)) * 0.5
        }
        return buffer
    }
}
