import XCTest
@testable import WordBitesKit

final class WordFinderTests: XCTestCase {
    private func makeFinder(words: [String]) -> WordFinder {
        WordFinder(dictionary: WordDictionary(words: words))
    }

    func testFindsAllWordsFromSingleTiles() {
        let finder = makeFinder(words: ["cat", "car", "at"])
        let tiles: [Tile] = ["c", "a", "t", "r"].map { .single(SingleTile(letter: Character($0))) }
        let results = finder.allPossibleWords(from: tiles)
        XCTAssertEqual(results, ["CAT", "CAR"])
    }

    func testDoubleTileContributesFixedOrder() {
        let finder = makeFinder(words: ["chat", "hat"])
        let tiles: [Tile] = [
            .double(DoubleTile(firstLetter: "c", secondLetter: "h", orientation: .horizontal)),
            .single(SingleTile(letter: "a")),
            .single(SingleTile(letter: "t"))
        ]
        let results = finder.allPossibleWords(from: tiles)
        XCTAssertTrue(results.contains("CHAT"))
        XCTAssertFalse(results.contains("HAT"), "the double tile can't be split to expose just H")
    }

    func testEachTileUsedAtMostOncePerWord() {
        // Only one "A" tile exists; "AA" should never appear even though "aa"
        // is in the dictionary, since that would need the tile twice.
        let finder = makeFinder(words: ["aa", "cat"])
        let tiles: [Tile] = ["c", "a", "t"].map { .single(SingleTile(letter: Character($0))) }
        let results = finder.allPossibleWords(from: tiles)
        XCTAssertFalse(results.contains("AA"))
        XCTAssertTrue(results.contains("CAT"))
    }

    func testRealDictionaryFindsMultipleWordsFromCommonLetters() throws {
        let dictionary = try WordDictionary.loadEnable1()
        let finder = WordFinder(dictionary: dictionary)
        let tiles: [Tile] = ["e", "a", "r", "s", "t", "n"].map { .single(SingleTile(letter: Character($0))) }
        let results = finder.allPossibleWords(from: tiles)
        XCTAssertTrue(results.contains("EAR"))
        XCTAssertTrue(results.contains("EARN"))
        XCTAssertTrue(results.contains("RANTS") || results.contains("EARNS"))
        XCTAssertGreaterThan(results.count, 5)
    }
}
