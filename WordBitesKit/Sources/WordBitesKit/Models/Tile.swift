import Foundation

/// A single-letter tile.
public struct SingleTile: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let letter: Character

    public init(id: UUID = UUID(), letter: Character) {
        precondition(letter.isLetter, "Tile letter must be a letter")
        self.id = id
        self.letter = Character(letter.uppercased())
    }
}

/// A fixed, immovable pair of letters occupying two adjacent cells in a line.
/// Reading order (first, then second) matches how the bigram was sampled and
/// does not change once dealt. Orientation is assigned at deal time and is
/// immutable — the player can move the tile but not rotate or split it.
public struct DoubleTile: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let firstLetter: Character
    public let secondLetter: Character
    public let orientation: TileOrientation

    public init(id: UUID = UUID(), firstLetter: Character, secondLetter: Character, orientation: TileOrientation) {
        precondition(firstLetter.isLetter && secondLetter.isLetter, "Tile letters must be letters")
        self.id = id
        self.firstLetter = Character(firstLetter.uppercased())
        self.secondLetter = Character(secondLetter.uppercased())
        self.orientation = orientation
    }

    public var text: String {
        String([firstLetter, secondLetter])
    }
}

public enum Tile: Identifiable, Equatable, Sendable {
    case single(SingleTile)
    case double(DoubleTile)

    public var id: UUID {
        switch self {
        case .single(let tile): return tile.id
        case .double(let tile): return tile.id
        }
    }

    /// Number of cells this tile occupies on the board.
    public var cellCount: Int {
        switch self {
        case .single: return 1
        case .double: return 2
        }
    }

    /// Letters in fixed reading order.
    public var letters: [Character] {
        switch self {
        case .single(let tile): return [tile.letter]
        case .double(let tile): return [tile.firstLetter, tile.secondLetter]
        }
    }

    public var vowelCount: Int {
        letters.filter { Self.vowels.contains($0) }.count
    }

    static let vowels: Set<Character> = ["A", "E", "I", "O", "U"]
}
