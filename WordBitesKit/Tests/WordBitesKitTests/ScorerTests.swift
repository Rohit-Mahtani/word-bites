import XCTest
@testable import WordBitesKit

final class ScorerTests: XCTestCase {
    func testScoringTableExactValues() {
        XCTAssertEqual(Scorer.points(forLength: 3), 100)
        XCTAssertEqual(Scorer.points(forLength: 4), 400)
        XCTAssertEqual(Scorer.points(forLength: 5), 800)
        XCTAssertEqual(Scorer.points(forLength: 6), 1400)
        XCTAssertEqual(Scorer.points(forLength: 7), 1800)
        XCTAssertEqual(Scorer.points(forLength: 8), 2200)
        XCTAssertEqual(Scorer.points(forLength: 9), 2600)
    }

    func testTwoLetterWordsAreUnscored() {
        XCTAssertNil(Scorer.points(forLength: 2))
    }

    func testTenLetterWordsAreUnscored() {
        XCTAssertNil(Scorer.points(forLength: 10))
    }

    func testPointsForWordUsesLength() {
        XCTAssertEqual(Scorer.points(for: "cat"), 100)
        XCTAssertEqual(Scorer.points(for: "birthday"), 2200)
    }
}
