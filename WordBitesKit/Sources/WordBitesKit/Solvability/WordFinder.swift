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
    /// ordered subset of `tiles`, each tile used at most once per word, in a
    /// way that's actually assemblable on the physical board. A word is
    /// always read along one straight line (a row or a column), so this
    /// runs the search once per line direction and unions the results: in
    /// the horizontal pass, a horizontal double tile contributes both its
    /// letters together (its two cells are already adjacent in that row —
    /// there's no way to use one and not the other) while a vertical double
    /// can only ever have one of its two cells actually sit in that row (the
    /// other is in an adjacent row), so it contributes either letter alone,
    /// never both — and vice versa for the vertical pass.
    public func allPossibleWords(from tiles: [Tile]) -> Set<String> {
        var found = Set<String>()
        for direction in [TileOrientation.horizontal, .vertical] {
            var used = Array(repeating: false, count: tiles.count)
            search(tiles: tiles, direction: direction, used: &used, current: "", found: &found)
        }
        return found
    }

    private func search(
        tiles: [Tile],
        direction: TileOrientation,
        used: inout [Bool],
        current: String,
        found: inout Set<String>
    ) {
        if current.count >= WordDictionary.minimumWordLength, dictionary.isValidWord(current) {
            found.insert(current)
        }
        guard current.count < SolvabilityChecker.maxWordLength else { return }

        for i in tiles.indices where !used[i] {
            used[i] = true
            for extension_ in tiles[i].extensions(forLineDirection: direction) {
                let candidate = current + extension_
                guard candidate.count <= SolvabilityChecker.maxWordLength, dictionary.hasPrefix(candidate) else { continue }
                search(tiles: tiles, direction: direction, used: &used, current: candidate, found: &found)
            }
            used[i] = false
        }
    }
}
