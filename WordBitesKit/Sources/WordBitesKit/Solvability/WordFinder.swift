import Foundation

/// Finds every valid word a tile set can produce, for the post-round solver
/// screen. Unlike `SolvabilityChecker` (which stops at the first word that
/// uses a given tile), this exhaustively collects every distinct match —
/// same trie-pruned search shape, just without the early exit.
public struct WordFinder: Sendable {
    private let dictionary: WordDictionary

    public init(dictionary: WordDictionary) {
        self.dictionary = dictionary
    }

    /// All distinct valid words (3-9 letters) formable by concatenating some
    /// ordered subset of `tiles`, each tile used at most once per word,
    /// double tiles contributing both letters in their fixed reading order.
    public func allPossibleWords(from tiles: [Tile]) -> Set<String> {
        var found = Set<String>()
        var used = Array(repeating: false, count: tiles.count)
        search(tiles: tiles, used: &used, current: "", found: &found)
        return found
    }

    private func search(tiles: [Tile], used: inout [Bool], current: String, found: inout Set<String>) {
        if current.count >= WordDictionary.minimumWordLength, dictionary.isValidWord(current) {
            found.insert(current)
        }
        guard current.count < SolvabilityChecker.maxWordLength else { return }

        for i in tiles.indices where !used[i] {
            let candidate = current + String(tiles[i].letters)
            guard candidate.count <= SolvabilityChecker.maxWordLength, dictionary.hasPrefix(candidate) else { continue }
            used[i] = true
            search(tiles: tiles, used: &used, current: candidate, found: &found)
            used[i] = false
        }
    }
}
