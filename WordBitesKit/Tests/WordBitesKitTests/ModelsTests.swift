import XCTest
@testable import WordBitesKit

final class ModelsTests: XCTestCase {
    func testPositionOffsetHorizontal() {
        let p = Position(column: 2, row: 3)
        XCTAssertEqual(p.offset(by: 1, direction: .horizontal), Position(column: 3, row: 3))
        XCTAssertEqual(p.offset(by: -1, direction: .horizontal), Position(column: 1, row: 3))
    }

    func testPositionOffsetVertical() {
        let p = Position(column: 2, row: 3)
        XCTAssertEqual(p.offset(by: 1, direction: .vertical), Position(column: 2, row: 4))
    }

    func testSingleTileUppercasesLetter() {
        let tile = SingleTile(letter: "a")
        XCTAssertEqual(tile.letter, "A")
    }

    func testDoubleTileVowelCount() {
        let tile = DoubleTile(firstLetter: "t", secondLetter: "h", orientation: .horizontal)
        XCTAssertEqual(Tile.double(tile).vowelCount, 0)

        let vowelTile = DoubleTile(firstLetter: "a", secondLetter: "e", orientation: .vertical)
        XCTAssertEqual(Tile.double(vowelTile).vowelCount, 2)
    }

    func testBoardPlaceSingleTileAndReadWord() {
        var board = Board()
        let t = SingleTile(letter: "c")
        let placement = Placement(tileID: t.id, origin: Position(column: 0, row: 0), direction: .horizontal)
        XCTAssertTrue(board.place(.single(t), at: placement))
        XCTAssertEqual(board.letter(at: Position(column: 0, row: 0)), "C")
    }

    func testBoardPlaceDoubleTileHorizontal() {
        var board = Board()
        let t = DoubleTile(firstLetter: "t", secondLetter: "h", orientation: .horizontal)
        let placement = Placement(tileID: t.id, origin: Position(column: 0, row: 0), direction: .horizontal)
        XCTAssertTrue(board.place(.double(t), at: placement))
        XCTAssertEqual(board.letter(at: Position(column: 0, row: 0)), "T")
        XCTAssertEqual(board.letter(at: Position(column: 1, row: 0)), "H")
    }

    func testBoardPlaceOutOfBoundsFails() {
        var board = Board()
        let t = SingleTile(letter: "z")
        let placement = Placement(tileID: t.id, origin: Position(column: 100, row: 0), direction: .horizontal)
        XCTAssertFalse(board.place(.single(t), at: placement))
    }

    func testBoardPlaceConflictingLetterFails() {
        var board = Board()
        let t1 = SingleTile(letter: "a")
        let t2 = SingleTile(letter: "b")
        let origin = Position(column: 0, row: 0)
        XCTAssertTrue(board.place(.single(t1), at: Placement(tileID: t1.id, origin: origin, direction: .horizontal)))
        XCTAssertFalse(board.place(.single(t2), at: Placement(tileID: t2.id, origin: origin, direction: .horizontal)))
    }

    func testBoardWordThroughReadsFullRun() {
        var board = Board()
        let letters: [Character] = ["C", "A", "T"]
        for (i, ch) in letters.enumerated() {
            board.setLetter(ch, at: Position(column: i, row: 0))
        }
        XCTAssertEqual(board.word(through: Position(column: 1, row: 0), direction: .horizontal), "CAT")
    }

    func testBoardWordThroughSingleLetterIsNil() {
        var board = Board()
        board.setLetter("X", at: Position(column: 0, row: 0))
        XCTAssertNil(board.word(through: Position(column: 0, row: 0), direction: .horizontal))
    }

    func testDealSatisfiesHardConstraints() {
        let singles = (0..<6).map { _ in SingleTile(letter: "t") } // 0 vowels from singles
        let doubles = (0..<5).map { _ in DoubleTile(firstLetter: "a", secondLetter: "e", orientation: .horizontal) } // 2 vowels each = 10
        let deal = Deal(singleTiles: singles, doubleTiles: doubles)
        XCTAssertEqual(deal.vowelCount, 10)
        XCTAssertFalse(deal.satisfiesHardConstraints)
    }

    func testDealWrongTileCountFailsConstraints() {
        let singles = (0..<5).map { _ in SingleTile(letter: "e") }
        let doubles = (0..<5).map { _ in DoubleTile(firstLetter: "t", secondLetter: "h", orientation: .horizontal) }
        let deal = Deal(singleTiles: singles, doubleTiles: doubles)
        XCTAssertFalse(deal.satisfiesHardConstraints)
    }
}
