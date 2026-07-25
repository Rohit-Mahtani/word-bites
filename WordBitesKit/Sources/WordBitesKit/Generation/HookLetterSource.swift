import Foundation

/// Supplies the "hook" letters that surround an anchor word in a
/// high-score deal — everything that isn't part of guaranteeing the anchor
/// word itself is spellable. A pluggable extension point: a future
/// data-driven source (e.g. pro-player hook-letter rankings) can bias which
/// letters/bigrams get chosen without changing `HighScoreBoardGenerator`'s
/// structure. `anchorLetters` is threaded through so such a source can
/// favor letters that combine well with the specific anchor in play.
public protocol HookLetterSource: Sendable {
    func candidateSingleLetters<R: RandomNumberGenerator>(
        count: Int, anchorLetters: Set<Character>, using rng: inout R
    ) -> [Character]

    func candidateBigrams<R: RandomNumberGenerator>(
        count: Int, anchorLetters: Set<Character>, using rng: inout R
    ) -> [(first: Character, second: Character)]
}

/// Default hook-letter source: ordinary English letter/bigram frequency,
/// with no special preference for or against the anchor's own letters.
public struct FrequencyHookLetterSource: HookLetterSource {
    private let bigramPool: BigramPool

    public init(bigramPool: BigramPool) {
        self.bigramPool = bigramPool
    }

    public func candidateSingleLetters<R: RandomNumberGenerator>(
        count: Int, anchorLetters: Set<Character>, using rng: inout R
    ) -> [Character] {
        (0..<max(0, count)).map { _ in LetterFrequency.sample(using: &rng) }
    }

    public func candidateBigrams<R: RandomNumberGenerator>(
        count: Int, anchorLetters: Set<Character>, using rng: inout R
    ) -> [(first: Character, second: Character)] {
        (0..<max(0, count)).map { _ in bigramPool.sample(using: &rng) }
    }
}
