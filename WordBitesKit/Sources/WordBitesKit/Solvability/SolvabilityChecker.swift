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
/// and the longest line the board supports (9, since the board is 8 wide x
/// 9 long).
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
        guard current.count < Self.maxWordLength else { return false }

        for i in tiles.indices where !used[i] {
            used[i] = true
            for extension_ in tiles[i].extensions(forLineDirection: direction) {
                let candidate = current + extension_
                guard candidate.count <= Self.maxWordLength, dictionary.hasPrefix(candidate) else { continue }

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
