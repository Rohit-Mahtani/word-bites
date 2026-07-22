import Foundation

/// The 8-wide x 9-long grid tiles are dragged onto to form words.
public struct Board: Sendable {
    public static let columnCount = 8
    public static let rowCount = 9

    private var grid: [[Character?]]

    public init() {
        grid = Array(repeating: Array(repeating: nil, count: Board.columnCount), count: Board.rowCount)
    }

    public func isInBounds(_ position: Position) -> Bool {
        position.column >= 0 && position.column < Board.columnCount &&
        position.row >= 0 && position.row < Board.rowCount
    }

    public func letter(at position: Position) -> Character? {
        guard isInBounds(position) else { return nil }
        return grid[position.row][position.column]
    }

    public mutating func setLetter(_ letter: Character?, at position: Position) {
        guard isInBounds(position) else { return }
        grid[position.row][position.column] = letter
    }

    /// Cells a tile would occupy starting at `origin`, running in `direction`.
    public static func cells(origin: Position, cellCount: Int, direction: TileOrientation) -> [Position] {
        (0..<cellCount).map { origin.offset(by: $0, direction: direction) }
    }

    /// Places a tile's letters at `placement`. Fails (without mutating the board)
    /// if any target cell is out of bounds or already holds a conflicting letter.
    @discardableResult
    public mutating func place(_ tile: Tile, at placement: Placement) -> Bool {
        let cells = Board.cells(origin: placement.origin, cellCount: tile.cellCount, direction: placement.direction)
        let letters = tile.letters
        for (cell, letter) in zip(cells, letters) {
            guard isInBounds(cell) else { return false }
            if let existing = self.letter(at: cell), existing != letter { return false }
        }
        for (cell, letter) in zip(cells, letters) {
            setLetter(letter, at: cell)
        }
        return true
    }

    /// Removes a tile's letters from `placement`, clearing only cells not
    /// shared with another still-placed tile (caller is responsible for
    /// re-placing anything that should remain).
    public mutating func remove(_ tile: Tile, at placement: Placement) {
        let cells = Board.cells(origin: placement.origin, cellCount: tile.cellCount, direction: placement.direction)
        for cell in cells {
            setLetter(nil, at: cell)
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
