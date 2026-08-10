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
        XCTAssertTrue(results.contains("CHAT"), "both letters together, in fixed order")
        // The board is 2D: a double tile's two cells can land in two
        // different physical lines (e.g. the C in a horizontal word, the H
        // jutting into an adjacent row unused by that word), so a live round
        // can legitimately score HAT using just this tile's H. The solver
        // must find it too, or it silently under-reports real, scoreable words.
        XCTAssertTrue(results.contains("HAT"), "the double tile's second letter alone is a legitimate contribution")
    }

    func testDoubleTileLetterUsableIndividually() {
        // Same double tile (C/H) combined with the same remaining tiles (A, T)
        // can spell two different complete words depending on which single
        // letter of the double gets used — CAT via the first letter alone,
        // HAT via the second letter alone — never both at once (that tile is
        // only used once per word).
        let finder = makeFinder(words: ["cat", "hat"])
        let tiles: [Tile] = [
            .double(DoubleTile(firstLetter: "c", secondLetter: "h", orientation: .horizontal)),
            .single(SingleTile(letter: "a")),
            .single(SingleTile(letter: "t"))
        ]
        let results = finder.allPossibleWords(from: tiles)
        XCTAssertEqual(results, ["CAT", "HAT"])
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

    func testFindsWordUsingDoubleTileInTheMiddle() {
        // Regression test for a real report: a 7-letter word built from 5
        // singles + 1 double tile straddling the middle of the word, not
        // just sitting conveniently at one end.
        let finder = makeFinder(words: ["panders", "pander"])
        let tiles: [Tile] = [
            .single(SingleTile(letter: "p")),
            .single(SingleTile(letter: "a")),
            .single(SingleTile(letter: "n")),
            .single(SingleTile(letter: "d")),
            .double(DoubleTile(firstLetter: "e", secondLetter: "r", orientation: .horizontal)),
            .single(SingleTile(letter: "s"))
        ]
        let results = finder.allPossibleWords(from: tiles)
        XCTAssertTrue(results.contains("PANDERS"), "5 singles + 1 mid-word double tile should combine to PANDERS")
        XCTAssertTrue(results.contains("PANDER"), "the same double tile should also work at the end, for PANDER")
    }

    func testFindsWordUsingTwoDoubleTiles() {
        let finder = makeFinder(words: ["handler"])
        let tiles: [Tile] = [
            .single(SingleTile(letter: "h")),
            .double(DoubleTile(firstLetter: "a", secondLetter: "n", orientation: .horizontal)),
            .single(SingleTile(letter: "d")),
            .single(SingleTile(letter: "l")),
            .double(DoubleTile(firstLetter: "e", secondLetter: "r", orientation: .horizontal))
        ]
        let results = finder.allPossibleWords(from: tiles)
        XCTAssertTrue(results.contains("HANDLER"), "H + [AN] + D + L + [ER] should combine to HANDLER")
    }

    func testWordNeedingTwoConflictingOrientationDoublesIsNotFound() {
        // HANDLER needs [AN] and [ER] both contributing their full pair --
        // only possible if both doubles share the line's own direction. Here
        // [AN] is vertical and [ER] is horizontal: no single straight line
        // can use both of them whole at once, so HANDLER must not be found,
        // even though the old (direction-blind) model would have allowed it.
        let finder = makeFinder(words: ["handler"])
        let tiles: [Tile] = [
            .single(SingleTile(letter: "h")),
            .double(DoubleTile(firstLetter: "a", secondLetter: "n", orientation: .vertical)),
            .single(SingleTile(letter: "d")),
            .single(SingleTile(letter: "l")),
            .double(DoubleTile(firstLetter: "e", secondLetter: "r", orientation: .horizontal))
        ]
        let results = finder.allPossibleWords(from: tiles)
        XCTAssertFalse(results.contains("HANDLER"), "the two doubles' orientations can never both match one straight line")
    }

    func testWordExceedingHorizontalLineLengthIsNotFoundEvenIfLettersExist() {
        // Reproduces a reported bug: CHANDLERS is 9 letters, but a
        // horizontal row is only 8 cells wide. Every letter is technically
        // available by pulling one letter from each of several different
        // vertical doubles -- but those doubles are scattered across
        // different rows in a real layout, so cramming all 9 letters into
        // one horizontal row is physically impossible no matter how they're
        // dragged. The solver must not claim it's possible.
        let finder = makeFinder(words: ["chandlers"])
        let tiles: [Tile] = [
            .single(SingleTile(letter: "c")),
            .single(SingleTile(letter: "n")),
            .single(SingleTile(letter: "l")),
            .single(SingleTile(letter: "r")),
            .single(SingleTile(letter: "s")),
            .double(DoubleTile(firstLetter: "h", secondLetter: "m", orientation: .vertical)),
            .double(DoubleTile(firstLetter: "o", secondLetter: "a", orientation: .vertical)),
            .double(DoubleTile(firstLetter: "d", secondLetter: "g", orientation: .vertical)),
            .double(DoubleTile(firstLetter: "s", secondLetter: "e", orientation: .vertical))
        ]
        let results = finder.allPossibleWords(from: tiles)
        XCTAssertFalse(results.contains("CHANDLERS"), "9 letters can never fit in an 8-cell-wide horizontal row")
    }

    func testRealDictionaryFindsMultipleWordsFromCommonLetters() throws {
        let dictionary = try WordDictionary.loadDefault()
        let finder = WordFinder(dictionary: dictionary)
        let tiles: [Tile] = ["e", "a", "r", "s", "t", "n"].map { .single(SingleTile(letter: Character($0))) }
        let results = finder.allPossibleWords(from: tiles)
        XCTAssertTrue(results.contains("EAR"))
        XCTAssertTrue(results.contains("EARN"))
        XCTAssertTrue(results.contains("RANTS") || results.contains("EARNS"))
        XCTAssertGreaterThan(results.count, 5)
    }

    func testArrangementFromSingleTiles() {
        let finder = makeFinder(words: ["cat"])
        let tiles: [Tile] = ["c", "a", "t"].map { .single(SingleTile(letter: Character($0))) }
        let arrangement = finder.arrangement(forWord: "cat", tiles: tiles)
        XCTAssertEqual(arrangement?.slots, [.single("C"), .single("A"), .single("T")])
    }

    func testArrangementInlinesDoubleTileAlignedWithWordDirection() {
        // CHAT read horizontally, with [CH] a horizontal double: both its
        // letters are consecutive slots since the tile's orientation matches
        // the word's own direction.
        let finder = makeFinder(words: ["chat"])
        let tiles: [Tile] = [
            .double(DoubleTile(firstLetter: "c", secondLetter: "h", orientation: .horizontal)),
            .single(SingleTile(letter: "a")),
            .single(SingleTile(letter: "t"))
        ]
        let arrangement = finder.arrangement(forWord: "chat", tiles: tiles)
        XCTAssertEqual(arrangement?.slots, [
            .doubleInline(letter: "C", isFirstOfPair: true),
            .doubleInline(letter: "H", isFirstOfPair: false),
            .single("A"),
            .single("T")
        ])
    }

    func testArrangementCarriesUnusedPartnerLetterForPerpendicularDouble() {
        // HAT read horizontally, but [C,H] is a *vertical* double tile — only
        // its H actually sits in this row, so the slot should carry the
        // unused C alongside it (still physically attached to the tile) with
        // usedIsFirst = false, since H is the double's second letter.
        let finder = makeFinder(words: ["hat"])
        let tiles: [Tile] = [
            .double(DoubleTile(firstLetter: "c", secondLetter: "h", orientation: .vertical)),
            .single(SingleTile(letter: "a")),
            .single(SingleTile(letter: "t"))
        ]
        let arrangement = finder.arrangement(forWord: "hat", tiles: tiles)
        XCTAssertEqual(arrangement?.slots, [
            .doublePerpendicular(usedLetter: "H", otherLetter: "C", usedIsFirst: false),
            .single("A"),
            .single("T")
        ])
    }

    func testArrangementReturnsNilForUnformableWord() {
        let finder = makeFinder(words: ["cat", "dog"])
        let tiles: [Tile] = ["c", "a", "t"].map { .single(SingleTile(letter: Character($0))) }
        XCTAssertNil(finder.arrangement(forWord: "dog", tiles: tiles))
    }

    func testArrangementUsableLetterConcatenationMatchesTheWord() throws {
        // Every slot's usedLetter, concatenated in order, must spell the
        // word exactly -- true for any arrangement finder returns.
        let dictionary = (try? WordDictionary.loadDefault()) ?? WordDictionary(words: ["pander", "panders"])
        let finder = WordFinder(dictionary: dictionary)
        let tiles: [Tile] = [
            .single(SingleTile(letter: "p")),
            .single(SingleTile(letter: "a")),
            .single(SingleTile(letter: "n")),
            .single(SingleTile(letter: "d")),
            .double(DoubleTile(firstLetter: "e", secondLetter: "r", orientation: .horizontal)),
            .single(SingleTile(letter: "s"))
        ]
        for word in ["PANDERS", "PANDER"] {
            let arrangement = try XCTUnwrap(finder.arrangement(forWord: word, tiles: tiles))
            let spelled = String(arrangement.slots.map(\.usedLetter))
            XCTAssertEqual(spelled, word)
        }
    }
}
