import Foundation

/// A cell on the board grid. `column` runs 0..<Board.columnCount (width),
/// `row` runs 0..<Board.rowCount (length).
public struct Position: Hashable, Sendable {
    public let column: Int
    public let row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }

    public func offset(by delta: Int, direction: TileOrientation) -> Position {
        switch direction {
        case .horizontal:
            return Position(column: column + delta, row: row)
        case .vertical:
            return Position(column: column, row: row + delta)
        }
    }
}

public enum TileOrientation: Sendable {
    case horizontal
    case vertical
}
