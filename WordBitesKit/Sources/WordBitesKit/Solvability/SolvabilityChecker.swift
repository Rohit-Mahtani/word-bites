import Foundation

/// Checks that a deal isn't "dead" before it's presented to the player.
///
/// Definition used here (deliberately looser than literal Scrabble-style
/// board-fill, since the real game lets tiles be dragged in and out of the
/// grid and re-combined freely during the timer rather than solving one
/// static layout): a deal is solvable iff every one of its 11 tiles can
/// participate in at least one valid dictionary word formed by concatenating
/// some ordered subset of the deal's tiles, in a way that's actually
/// assemblable on the physical board. A word is always read along one
/// straight line (a row or a column): a double tile oriented the same way
/// as that line contributes both its letters together (its two cells are
/// already adjacent within it — there's no way to use one and not the
/// other), while a double tile perpendicular to the line can only ever have
/// one of its two cells actually sit in it, so it contributes either letter
/// alone, never both. Word length must fall within the dictionary's minimum
/// and whichever line direction it's being read along actually supports: a
/// horizontal line can be at most as long as the board is wide, a vertical
/// line at most as long as the board is tall — using the *overall* longest
/// line for both directions would wrongly let words too long for a
/// horizontal row get "found" there by stitching together single letters
/// pulled from several different vertical doubles scattered across
/// different rows, which can never actually fit in one row.
public struct SolvabilityChecker: Sendable {
    public static let maxWordLength = max(Board.columnCount, Board.rowCount)

    private let dictionary: WordDictionary

    public init(dictionary: WordDictionary) {
        self.dictionary = dictionary
    }

    /// The longest word obtainable along a line running in `direction`.
    static func maxWordLength(for direction: TileOrientation) -> Int {
        direction == .horizontal ? Board.columnCount : Board.rowCount
    }

    public func isSolvable(_ deal: Deal) -> Bool {
        let tiles = deal.allTiles
        return tiles.allSatisfy { canFormWord(containing: $0, from: tiles) }
    }

    private func canFormWord(containing requiredTile: Tile, from tiles: [Tile]) -> Bool {
        guard let requiredIndex = tiles.firstIndex(where: { $0.id == requiredTile.id }) else { return false }
        for direction in [TileOrientation.horizontal, .vertical] {
            var used = Array(repeating: false, count: tiles.count)
            if search(current: "", usedRequiredTile: false, tiles: tiles, direction: direction, requiredIndex: requiredIndex, used: &used) {
                return true
            }
        }
        return false
    }

    private func search(
        current: String,
        usedRequiredTile: Bool,
        tiles: [Tile],
        direction: TileOrientation,
        requiredIndex: Int,
        used: inout [Bool]
    ) -> Bool {
        if usedRequiredTile,
           current.count >= WordDictionary.minimumWordLength,
           dictionary.isValidWord(current) {
            return true
        }
        let limit = Self.maxWordLength(for: direction)
        guard current.count < limit else { return false }

        for i in tiles.indices where !used[i] {
            used[i] = true
            for extension_ in tiles[i].extensions(forLineDirection: direction) {
                let candidate = current + extension_
                guard candidate.count <= limit, dictionary.hasPrefix(candidate) else { continue }

                let found = search(
                    current: candidate,
                    usedRequiredTile: usedRequiredTile || i == requiredIndex,
                    tiles: tiles,
                    direction: direction,
                    requiredIndex: requiredIndex,
                    used: &used
                )
                if found { used[i] = false; return true }
            }
            used[i] = false
        }
        return false
    }
}
