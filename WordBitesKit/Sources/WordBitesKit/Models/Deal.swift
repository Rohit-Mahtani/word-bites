import Foundation

/// The 11 tiles dealt for one round: exactly 6 single-letter tiles and
/// 5 double-letter tiles, with a total vowel count of 5 or 6 across all tiles.
public struct Deal: Sendable {
    public static let singleTileCount = 6
    public static let doubleTileCount = 5
    public static let validVowelCounts: Set<Int> = [5, 6]

    public let singleTiles: [SingleTile]
    public let doubleTiles: [DoubleTile]

    public init(singleTiles: [SingleTile], doubleTiles: [DoubleTile]) {
        self.singleTiles = singleTiles
        self.doubleTiles = doubleTiles
    }

    public var allTiles: [Tile] {
        singleTiles.map(Tile.single) + doubleTiles.map(Tile.double)
    }

    public var vowelCount: Int {
        allTiles.reduce(0) { $0 + $1.vowelCount }
    }

    /// True iff this deal satisfies the hard constraints from the spec
    /// (tile counts, vowel total). Does not check solvability.
    public var satisfiesHardConstraints: Bool {
        singleTiles.count == Self.singleTileCount &&
        doubleTiles.count == Self.doubleTileCount &&
        Self.validVowelCounts.contains(vowelCount)
    }
}
