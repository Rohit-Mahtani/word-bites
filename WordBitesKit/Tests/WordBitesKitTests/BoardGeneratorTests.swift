import XCTest
@testable import WordBitesKit

final class BoardGeneratorTests: XCTestCase {
    // Built once and reused across tests in this class; scanning the full
    // dictionary to build the bigram pool is the expensive part.
    static let dictionary: WordDictionary = try! WordDictionary.loadEnable1()

    static let bigramPool: BigramPool = BigramPool(dictionary: dictionary)

    static let solvabilityChecker: SolvabilityChecker = SolvabilityChecker(dictionary: dictionary)

    func testGeneratedDealSatisfiesHardConstraints() throws {
        let generator = BoardGenerator(bigramPool: Self.bigramPool, solvabilityChecker: Self.solvabilityChecker)

        for seed in UInt64(0)..<20 {
            var rng = SeededRNG(seed: seed)
            let deal = try generator.generateDeal(rng: &rng)
            XCTAssertEqual(deal.singleTiles.count, Deal.singleTileCount)
            XCTAssertEqual(deal.doubleTiles.count, Deal.doubleTileCount)
            XCTAssertTrue(Deal.validVowelCounts.contains(deal.vowelCount),
                          "vowel count \(deal.vowelCount) not in {5,6} for seed \(seed)")
            XCTAssertTrue(Self.solvabilityChecker.isSolvable(deal), "seed \(seed) produced an unsolvable deal")
        }
    }

    func testDoubleTileOrientationsCanBeBothKinds() throws {
        let generator = BoardGenerator(bigramPool: Self.bigramPool, solvabilityChecker: Self.solvabilityChecker)
        var rng = SeededRNG(seed: 99)
        var sawHorizontal = false
        var sawVertical = false
        for _ in 0..<50 {
            let deal = try generator.generateDeal(rng: &rng)
            for tile in deal.doubleTiles {
                switch tile.orientation {
                case .horizontal: sawHorizontal = true
                case .vertical: sawVertical = true
                }
            }
        }
        XCTAssertTrue(sawHorizontal)
        XCTAssertTrue(sawVertical)
    }

    func testDoubleTileLettersComeFromRealBigrams() throws {
        let generator = BoardGenerator(bigramPool: Self.bigramPool, solvabilityChecker: Self.solvabilityChecker)
        var rng = SeededRNG(seed: 5)
        let deal = try generator.generateDeal(rng: &rng)
        for tile in deal.doubleTiles {
            let bigram = tile.text
            let appearsInSomeWord = Self.dictionary.words.contains { $0.contains(bigram) }
            XCTAssertTrue(appearsInSomeWord, "\(bigram) should appear inside at least one dictionary word")
        }
    }
}
