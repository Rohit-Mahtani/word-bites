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
    /// ordered subset of `tiles`, each tile used at most once per word. A
    /// double tile contributes either both letters together (fixed reading
    /// order, never reversed) or just one of its two letters alone — the
    /// board is 2D, so a double tile's two cells can land in two different
    /// physical lines (e.g. one letter in a horizontal word, the other
    /// jutting into an adjacent row unused by that word), and both letters
    /// individually usable this way are legitimate, independent contributions.
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
            used[i] = true
            for extension_ in tileExtensions(for: tiles[i]) {
                let candidate = current + extension_
                guard candidate.count <= SolvabilityChecker.maxWordLength, dictionary.hasPrefix(candidate) else { continue }
                search(tiles: tiles, used: &used, current: candidate, found: &found)
            }
            used[i] = false
        }
    }

    /// The ways a single tile can extend a candidate string: a single tile
    /// offers only its one letter; a double tile offers both letters
    /// together (in fixed order) or either letter alone.
    private func tileExtensions(for tile: Tile) -> [String] {
        switch tile {
        case .single(let single):
            return [String(single.letter)]
        case .double(let double):
            return [
                String([double.firstLetter, double.secondLetter]),
                String(double.firstLetter),
                String(double.secondLetter)
            ]
        }
    }
}
