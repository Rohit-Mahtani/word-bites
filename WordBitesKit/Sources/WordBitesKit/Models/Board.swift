import Foundation

/// The 8-wide x 9-long grid tiles are dragged onto to form words.
public struct Board: Sendable {
    public static let columnCount = 8
    public static let rowCount = 9

    /// Occupancy is tracked by the owning tile's identity, not just its
    /// letter — two different tiles that happen to share a letter must
    /// never be treated as compatible occupants of the same cell.
    private struct Occupant: Sendable {
        let tileID: UUID
        let letter: Character
    }

    private var grid: [[Occupant?]]

    public init() {
        grid = Array(repeating: Array(repeating: nil, count: Board.columnCount), count: Board.rowCount)
    }

    public func isInBounds(_ position: Position) -> Bool {
        position.column >= 0 && position.column < Board.columnCount &&
        position.row >= 0 && position.row < Board.rowCount
    }

    public func letter(at position: Position) -> Character? {
        guard isInBounds(position) else { return nil }
        return grid[position.row][position.column]?.letter
    }

    /// The tile currently occupying `position`, if any.
    public func tileID(at position: Position) -> UUID? {
        guard isInBounds(position) else { return nil }
        return grid[position.row][position.column]?.tileID
    }

    /// Cells a tile would occupy starting at `origin`, running in `direction`.
    public static func cells(origin: Position, cellCount: Int, direction: TileOrientation) -> [Position] {
        (0..<cellCount).map { origin.offset(by: $0, direction: direction) }
    }

    /// Whether `tile` could be placed at `placement` right now: every
    /// target cell must be in bounds and either empty or already occupied
    /// by this same tile (so re-confirming a tile's current spot is always
    /// allowed, but a different tile can never be treated as compatible
    /// just because it happens to show the same letter).
    public func canPlace(_ tile: Tile, at placement: Placement) -> Bool {
        let cells = Board.cells(origin: placement.origin, cellCount: tile.cellCount, direction: placement.direction)
        for cell in cells {
            guard isInBounds(cell) else { return false }
            if let occupant = grid[cell.row][cell.column], occupant.tileID != tile.id { return false }
        }
        return true
    }

    /// Places a tile's letters at `placement`. Fails (without mutating the
    /// board) if any target cell is out of bounds or already occupied by a
    /// different tile.
    @discardableResult
    public mutating func place(_ tile: Tile, at placement: Placement) -> Bool {
        guard canPlace(tile, at: placement) else { return false }
        let cells = Board.cells(origin: placement.origin, cellCount: tile.cellCount, direction: placement.direction)
        for (cell, letter) in zip(cells, tile.letters) {
            grid[cell.row][cell.column] = Occupant(tileID: tile.id, letter: letter)
        }
        return true
    }

    /// Clears `tile`'s cells at `placement` — only cells `tile` itself
    /// still occupies are cleared, so this can never accidentally erase a
    /// different tile that has since moved in.
    public mutating func remove(_ tile: Tile, at placement: Placement) {
        let cells = Board.cells(origin: placement.origin, cellCount: tile.cellCount, direction: placement.direction)
        for cell in cells where grid[cell.row][cell.column]?.tileID == tile.id {
            grid[cell.row][cell.column] = nil
        }
    }

    /// The maximal contiguous run of filled cells passing through `position`
    /// along `direction`, e.g. for reading out a formed word. Returns nil if
    /// `position` is empty or the run is fewer than 2 letters.
    public func word(through position: Position, direction: TileOrientation) -> String? {
        guard letter(at: position) != nil else { return nil }

        var start = position
        while true {
            let prev = start.offset(by: -1, direction: direction)
            guard isInBounds(prev), letter(at: prev) != nil else { break }
            start = prev
        }

        var result = ""
        var current = start
        while isInBounds(current), let ch = letter(at: current) {
            result.append(ch)
            current = current.offset(by: 1, direction: direction)
        }
        return result.count >= 2 ? result : nil
    }
}
