import Foundation

/// Where a tile sits on the board. `direction` only matters for double tiles
/// (it must match the tile's fixed orientation); single tiles occupy one cell
/// so direction has no effect.
public struct Placement: Equatable, Sendable {
    public let tileID: UUID
    public let origin: Position
    public let direction: TileOrientation

    public init(tileID: UUID, origin: Position, direction: TileOrientation) {
        self.tileID = tileID
        self.origin = origin
        self.direction = direction
    }
}
