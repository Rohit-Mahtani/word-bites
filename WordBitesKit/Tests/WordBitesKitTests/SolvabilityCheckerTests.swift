import XCTest
@testable import WordBitesKit

final class SolvabilityCheckerTests: XCTestCase {
    private func makeChecker(words: [String]) -> SolvabilityChecker {
        SolvabilityChecker(dictionary: WordDictionary(words: words))
    }

    func testDealIsSolvableWhenAllTilesCombineIntoWords() {
        // CAT (single C, single A, single T) and DOG (single D, single O, single G)
        let checker = makeChecker(words: ["cat", "dog"])
        let singles = ["c", "a", "t", "d", "o", "g"].map { SingleTile(letter: Character($0)) }
        let doubles: [DoubleTile] = []
        let deal = Deal(singleTiles: singles, doubleTiles: doubles)
        XCTAssertTrue(checker.isSolvable(deal))
    }

    func testDealIsUnsolvableWhenATileCannotCombineIntoAnyWord() {
        let checker = makeChecker(words: ["cat", "dog"])
        // 'x' can't combine with any of these tiles to form "cat" or "dog".
        let singles = ["c", "a", "t", "d", "o", "x"].map { SingleTile(letter: Character($0)) }
        let deal = Deal(singleTiles: singles, doubleTiles: [])
        XCTAssertFalse(checker.isSolvable(deal))
    }

    func testDoubleTileParticipatesInWordWithFixedLetterOrder() {
        // "CH" + "AT" = "CHAT"
        let checker = makeChecker(words: ["chat"])
        let doubles = [
            DoubleTile(firstLetter: "c", secondLetter: "h", orientation: .horizontal),
            DoubleTile(firstLetter: "a", secondLetter: "t", orientation: .horizontal)
        ]
        let deal = Deal(singleTiles: [], doubleTiles: doubles)
        XCTAssertTrue(checker.isSolvable(deal))
    }

    func testReversedBigramOrderDoesNotCount() {
        // Dictionary only has "chat", but the tile is "HC" not "CH" -- fixed
        // reading order means it can't be flipped to spell "CHAT".
        let checker = makeChecker(words: ["chat"])
        let doubles = [
            DoubleTile(firstLetter: "h", secondLetter: "c", orientation: .horizontal),
            DoubleTile(firstLetter: "a", secondLetter: "t", orientation: .horizontal)
        ]
        let deal = Deal(singleTiles: [], doubleTiles: doubles)
        XCTAssertFalse(checker.isSolvable(deal))
    }

    func testWordsLongerThanMaxLineLengthAreNotConsidered() {
        // 10-letter word exceeds the 9-cell longest line on the board.
        let checker = makeChecker(words: ["abcdefghij"])
        let singles = "abcdefghij".map { SingleTile(letter: $0) }
        let deal = Deal(singleTiles: singles, doubleTiles: [])
        XCTAssertFalse(checker.isSolvable(deal))
    }

    func testRealDictionaryProducesSolvableHandPickedDeal() throws {
        let dictionary = try WordDictionary.loadEnable1()
        let checker = SolvabilityChecker(dictionary: dictionary)
        // Frequency-weighted common letters should always combine into words.
        let singles = ["e", "a", "r", "s", "t", "n"].map { SingleTile(letter: Character($0)) }
        let doubles = [
            DoubleTile(firstLetter: "t", secondLetter: "h", orientation: .horizontal),
            DoubleTile(firstLetter: "e", secondLetter: "r", orientation: .horizontal),
            DoubleTile(firstLetter: "a", secondLetter: "n", orientation: .vertical),
            DoubleTile(firstLetter: "i", secondLetter: "n", orientation: .vertical),
            DoubleTile(firstLetter: "o", secondLetter: "r", orientation: .horizontal)
        ]
        let deal = Deal(singleTiles: singles, doubleTiles: doubles)
        XCTAssertTrue(checker.isSolvable(deal))
    }
}
