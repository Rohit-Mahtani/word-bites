import XCTest
@testable import WordBitesKit

final class LetterFrequencyTests: XCTestCase {
    func testSampleAlwaysReturnsAKnownLetter() {
        var rng = SeededRNG(seed: 1)
        for _ in 0..<500 {
            let letter = LetterFrequency.sample(using: &rng)
            XCTAssertNotNil(LetterFrequency.weights[letter])
        }
    }

    func testDistributionSkewsTowardCommonLetters() {
        var rng = SeededRNG(seed: 42)
        var counts: [Character: Int] = [:]
        let iterations = 20_000
        for _ in 0..<iterations {
            let letter = LetterFrequency.sample(using: &rng)
            counts[letter, default: 0] += 1
        }
        // E is the most frequent letter; Z is the rarest. Over enough draws
        // the weighting should make E dramatically more common than Z.
        XCTAssertGreaterThan(counts["E"] ?? 0, counts["Z"] ?? 0)
        XCTAssertGreaterThan(counts["E"] ?? 0, iterations / 20)
    }
}

final class BigramPoolTests: XCTestCase {
    func testSampleReturnsOnlyKnownBigrams() {
        let pool = BigramPool(dictionaryWords: ["cat", "car", "dog"])
        var rng = SeededRNG(seed: 7)
        let validBigrams: Set<String> = ["CA", "AT", "AR", "DO", "OG"]
        for _ in 0..<200 {
            let (first, second) = pool.sample(using: &rng)
            XCTAssertTrue(validBigrams.contains(String([first, second])))
        }
    }

    func testEmptyDictionaryProducesEmptyPool() {
        let pool = BigramPool(dictionaryWords: [String]())
        XCTAssertTrue(pool.isEmpty)
    }
}
