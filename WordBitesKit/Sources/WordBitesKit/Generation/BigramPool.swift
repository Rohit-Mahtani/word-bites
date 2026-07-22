import Foundation

/// Pool of 2-letter sequences for double tiles, built by sliding a 2-letter
/// window across every word in the dictionary and weighting each bigram by
/// how often it occurs. Guarantees every double tile is found inside at
/// least one real word. Build once from a `WordDictionary` and reuse across
/// rounds — scanning the whole word list on every deal would be wasteful.
public struct BigramPool: Sendable {
    private let counts: [String: Int]
    private let totalCount: Int

    public init(dictionaryWords: some Sequence<String>) {
        var counts: [String: Int] = [:]
        for word in dictionaryWords {
            let chars = Array(word.uppercased())
            guard chars.count >= 2 else { continue }
            for i in 0..<(chars.count - 1) {
                guard chars[i].isLetter, chars[i + 1].isLetter else { continue }
                let bigram = String([chars[i], chars[i + 1]])
                counts[bigram, default: 0] += 1
            }
        }
        self.counts = counts
        self.totalCount = counts.values.reduce(0, +)
    }

    public init(dictionary: WordDictionary) {
        self.init(dictionaryWords: dictionary.words)
    }

    public var isEmpty: Bool { counts.isEmpty }

    /// Samples a bigram (two letters, fixed reading order) weighted by its
    /// occurrence frequency across the dictionary.
    public func sample(using rng: inout some RandomNumberGenerator) -> (first: Character, second: Character) {
        precondition(!counts.isEmpty, "Bigram pool was built from an empty dictionary")
        var threshold = Int.random(in: 0..<totalCount, using: &rng)
        for (bigram, count) in counts {
            if threshold < count {
                let chars = Array(bigram)
                return (chars[0], chars[1])
            }
            threshold -= count
        }
        let chars = Array(counts.keys.first!)
        return (chars[0], chars[1])
    }
}
