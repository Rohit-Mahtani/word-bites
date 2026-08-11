import WordBitesKit

/// One tile in a preset board: 1 letter for a single tile, 2 for a double
/// (in fixed reading order). `column`/`row` are only used to draw the mini
/// preview thumbnail -- matching the original screenshots exactly -- since
/// `CustomBoardStore` (which these presets feed into) only carries letters
/// and each double's orientation; actual gameplay positions are always
/// scattered fresh at deal time, same as any other custom board.
struct PresetTile {
    let letters: [Character]
    let orientation: TileOrientation
    let column: Int
    let row: Int
}

struct PresetBoard: Identifiable {
    let id: Int
    let name: String
    let tiles: [PresetTile]

    var singleLetters: [Character] { tiles.filter { $0.letters.count == 1 }.map { $0.letters[0] } }
    var doubleTiles: [(first: Character, second: Character, orientation: TileOrientation)] {
        tiles.filter { $0.letters.count == 2 }.map { ($0.letters[0], $0.letters[1], $0.orientation) }
    }
}

/// 10 boards copied exactly (letters, pairing, and layout) from real Word
/// Bites screenshots -- see the "Presets" screen off Custom Board.
enum PresetBoards {
    private static func single(_ letter: Character, _ column: Int, _ row: Int) -> PresetTile {
        PresetTile(letters: [letter], orientation: .horizontal, column: column, row: row)
    }

    private static func double(_ first: Character, _ second: Character, _ orientation: TileOrientation, _ column: Int, _ row: Int) -> PresetTile {
        PresetTile(letters: [first, second], orientation: orientation, column: column, row: row)
    }

    static let all: [PresetBoard] = [
        PresetBoard(id: 11, name: "God Board 1", tiles: [
            single("S", 0, 0), single("P", 6, 8), single("R", 1, 7), single("L", 3, 5),
            single("N", 4, 7), single("C", 4, 1),
            double("H", "M", .vertical, 2, 1),
            double("S", "E", .vertical, 7, 1),
            double("D", "G", .vertical, 7, 4),
            double("O", "A", .vertical, 5, 4),
            double("I", "T", .vertical, 0, 4)
        ]),
        PresetBoard(id: 12, name: "God Board 2", tiles: [
            single("R", 0, 1), single("S", 5, 1), single("I", 2, 2), single("N", 2, 4),
            single("C", 0, 6), single("E", 6, 8),
            double("G", "K", .vertical, 7, 0),
            double("L", "H", .vertical, 7, 3),
            double("O", "A", .vertical, 2, 6),
            double("M", "T", .vertical, 4, 5),
            double("D", "P", .vertical, 0, 3)
        ]),
        PresetBoard(id: 1, name: "Preset 1", tiles: [
            single("B", 0, 0), single("G", 0, 2), single("E", 0, 4), single("A", 1, 7),
            single("R", 2, 2), single("C", 6, 4),
            double("T", "S", .vertical, 6, 0),
            double("N", "D", .vertical, 4, 1),
            double("L", "E", .vertical, 3, 4),
            double("I", "N", .vertical, 6, 6),
            double("P", "A", .vertical, 4, 7)
        ]),
        PresetBoard(id: 2, name: "Preset 2", tiles: [
            single("S", 2, 0), single("E", 4, 0), single("L", 6, 0), single("A", 6, 2),
            single("O", 0, 3), single("G", 2, 4),
            double("M", "P", .horizontal, 3, 2),
            double("I", "C", .horizontal, 4, 4),
            double("N", "U", .horizontal, 5, 6),
            double("E", "R", .horizontal, 1, 7),
            double("T", "H", .horizontal, 6, 8)
        ]),
        PresetBoard(id: 3, name: "Preset 3", tiles: [
            single("T", 4, 0), single("L", 3, 2), single("S", 7, 3), single("P", 0, 4),
            single("R", 7, 6), single("G", 0, 8),
            double("E", "W", .horizontal, 6, 1),
            double("N", "U", .horizontal, 0, 2),
            double("V", "A", .horizontal, 2, 4),
            double("I", "E", .horizontal, 2, 6),
            double("C", "Y", .horizontal, 4, 8)
        ]),
        PresetBoard(id: 4, name: "Preset 4", tiles: [
            single("G", 6, 0), single("N", 0, 1), single("P", 3, 1), single("A", 0, 3),
            single("L", 5, 7), single("B", 7, 8),
            double("E", "X", .horizontal, 5, 2),
            double("T", "R", .horizontal, 2, 3),
            double("I", "C", .horizontal, 5, 5),
            double("I", "M", .horizontal, 0, 6),
            double("D", "S", .horizontal, 0, 8)
        ]),
        PresetBoard(id: 5, name: "Preset 5", tiles: [
            single("N", 0, 0), single("L", 3, 0), single("G", 5, 1), single("S", 1, 2),
            single("B", 3, 3), single("A", 4, 7),
            double("M", "P", .vertical, 7, 0),
            double("I", "E", .vertical, 1, 4),
            double("A", "C", .horizontal, 5, 4),
            double("U", "R", .vertical, 6, 6),
            double("E", "T", .vertical, 0, 7)
        ]),
        PresetBoard(id: 6, name: "Preset 6", tiles: [
            single("L", 5, 1), single("H", 3, 4), single("A", 6, 4), single("P", 4, 6),
            single("T", 7, 7), single("R", 5, 8),
            double("D", "E", .vertical, 3, 1),
            double("A", "M", .vertical, 7, 1),
            double("C", "O", .vertical, 1, 3),
            double("N", "F", .vertical, 0, 6),
            double("E", "S", .vertical, 2, 6)
        ]),
        PresetBoard(id: 7, name: "Preset 7", tiles: [
            single("L", 5, 0), single("P", 0, 2), single("E", 7, 4), single("T", 0, 6),
            single("C", 3, 7), single("A", 0, 8),
            double("U", "R", .horizontal, 2, 1),
            double("N", "G", .horizontal, 5, 2),
            double("F", "O", .horizontal, 2, 5),
            double("Y", "S", .horizontal, 6, 6),
            double("E", "N", .horizontal, 5, 8)
        ]),
        PresetBoard(id: 8, name: "Preset 8", tiles: [
            single("D", 0, 0), single("L", 3, 0), single("G", 0, 3), single("C", 2, 3),
            single("N", 0, 5), single("T", 7, 5),
            double("I", "S", .horizontal, 5, 1),
            double("I", "P", .horizontal, 4, 3),
            double("K", "E", .horizontal, 2, 5),
            double("U", "R", .horizontal, 1, 7),
            double("H", "A", .horizontal, 6, 7)
        ]),
        PresetBoard(id: 9, name: "Preset 9", tiles: [
            single("G", 0, 0), single("N", 7, 0), single("L", 1, 2), single("M", 3, 4),
            single("E", 0, 8), single("R", 2, 8),
            double("B", "O", .vertical, 4, 0),
            double("H", "A", .vertical, 6, 2),
            double("T", "E", .vertical, 1, 5),
            double("S", "O", .vertical, 6, 5),
            double("F", "I", .vertical, 4, 7)
        ]),
        // The source screenshot for this one was mid-round (tiles already
        // arranged into PLANTERS on the board), not a fresh deal like the
        // other 9 -- so unlike those, its preview positions below are a
        // fixed, deliberately-scattered layout rather than a copy of the
        // screenshot itself.
        PresetBoard(id: 10, name: "Preset 10", tiles: [
            single("G", 7, 0), single("C", 5, 0), single("N", 3, 3), single("B", 1, 3),
            single("T", 5, 6), single("P", 4, 8),
            double("R", "I", .vertical, 1, 0),
            double("A", "D", .vertical, 6, 3),
            double("E", "X", .vertical, 3, 5),
            double("O", "L", .vertical, 1, 6),
            double("E", "S", .vertical, 7, 6)
        ])
    ]
}
