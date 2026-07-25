import Foundation

/// Checks that a deal isn't "dead" before it's presented to the player.
///
/// Definition used here (deliberately looser than literal Scrabble-style
/// board-fill, since the real game lets tiles be dragged in and out of the
/// grid and re-combined freely during the timer rather than solving one
/// static layout): a deal is solvable iff every one of its 11 tiles can
/// participate in at least one valid dictionary word formed by concatenating
/// some ordered subset of the deal's tiles. A double tile may contribute
/// both letters together (fixed reading order, never reversed) or just one
/// of its two letters alone — the board is 2D, so a double tile's two cells
/// can land in two different physical lines, each letter independently
/// usable. Word length must fall within the dictionary's minimum and the
/// longest line the board supports (9, since the board is 8 wide x 9 long).
public struct SolvabilityChecker: Sendable {
    public static let maxWordLength = max(Board.columnCount, Board.rowCount)

    private let dictionary: WordDictionary

    public init(dictionary: WordDictionary) {
        self.dictionary = dictionary
    }

    public func isSolvable(_ deal: Deal) -> Bool {
        let tiles = deal.allTiles
        return tiles.allSatisfy { canFormWord(containing: $0, from: tiles) }
    }

    private func canFormWord(containing requiredTile: Tile, from tiles: [Tile]) -> Bool {
        guard let requiredIndex = tiles.firstIndex(where: { $0.id == requiredTile.id }) else { return false }
        var used = Array(repeating: false, count: tiles.count)
        return search(current: "", usedRequiredTile: false, tiles: tiles, requiredIndex: requiredIndex, used: &used)
    }

    private func search(
        current: String,
        usedRequiredTile: Bool,
        tiles: [Tile],
        requiredIndex: Int,
        used: inout [Bool]
    ) -> Bool {
        if usedRequiredTile,
           current.count >= WordDictionary.minimumWordLength,
           dictionary.isValidWord(current) {
            return true
        }
        guard current.count < Self.maxWordLength else { return false }

        for i in tiles.indices where !used[i] {
            used[i] = true
            for extension_ in tileExtensions(for: tiles[i]) {
                let candidate = current + extension_
                guard candidate.count <= Self.maxWordLength, dictionary.hasPrefix(candidate) else { continue }

                let found = search(
                    current: candidate,
                    usedRequiredTile: usedRequiredTile || i == requiredIndex,
                    tiles: tiles,
                    requiredIndex: requiredIndex,
                    used: &used
                )
                if found { used[i] = false; return true }
            }
            used[i] = false
        }
        return false
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
