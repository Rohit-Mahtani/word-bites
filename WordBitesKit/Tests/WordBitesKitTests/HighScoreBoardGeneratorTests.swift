import XCTest
@testable import WordBitesKit

final class HighScoreBoardGeneratorTests: XCTestCase {
    static let dictionary: WordDictionary = try! WordDictionary.loadEnable1()
    static let bigramPool = BigramPool(dictionary: dictionary)
    static let solvabilityChecker = SolvabilityChecker(dictionary: dictionary)
    static let wordFinder = WordFinder(dictionary: dictionary)

    private func makeGenerator() -> HighScoreBoardGenerator {
        HighScoreBoardGenerator(
            bigramPool: Self.bigramPool,
            solvabilityChecker: Self.solvabilityChecker,
            wordFinder: Self.wordFinder
        )
    }

    func testZeroPotentialStillSatisfiesHardConstraintsAndSolvability() throws {
        let generator = makeGenerator()
        for _ in 0..<5 {
            let deal = try generator.generateDeal(potential: 0, candidatePoolSize: 1)
            XCTAssertTrue(deal.satisfiesHardConstraints)
            XCTAssertTrue(Self.solvabilityChecker.isSolvable(deal))
        }
    }

    func testHighPotentialIncludesAnAnchorLetter() throws {
        let generator = makeGenerator()
        for _ in 0..<5 {
            let deal = try generator.generateDeal(potential: 1, candidatePoolSize: 3, maxAttemptsPerCandidate: 400)
            let singleLetters = Set(deal.singleTiles.map(\.letter))
            XCTAssertTrue(
                singleLetters.contains("C") || singleLetters.contains("T"),
                "expected the planters (C) or maligners (T) anchor among the singles, got \(singleLetters)"
            )
        }
    }

    func testHighPotentialNeverFusesTwoHookLettersIntoOneDouble() throws {
        let planters: Set<Character> = ["C", "I", "K", "D", "O"]
        let maligners: Set<Character> = ["T", "C", "O", "H", "D", "K"]
        let generator = makeGenerator()

        for _ in 0..<8 {
            let deal = try generator.generateDeal(potential: 1, candidatePoolSize: 3, maxAttemptsPerCandidate: 400)
            let singleLetters = Set(deal.singleTiles.map(\.letter))

            // Only maligners' extras include T+H together; only planters'
            // extras include I. Skip the rare case we can't tell which
            // archetype actually won, rather than guess and risk a flaky
            // false failure.
            let looksLikeMaligners = singleLetters.contains("T") && singleLetters.contains("H")
            let looksLikePlanters = singleLetters.contains("I") && !looksLikeMaligners
            guard looksLikeMaligners || looksLikePlanters else { continue }

            let activeHookLetters = looksLikeMaligners ? maligners : planters
            for double in deal.doubleTiles {
                let pair: Set<Character> = [double.firstLetter, double.secondLetter]
                let fusesHookLetters = pair.count == 2 && pair.isSubset(of: activeHookLetters)
                XCTAssertFalse(fusesHookLetters, "double tile \(double.text) fuses two hook letters together")
            }
        }
    }

    func testGeneratedDealsAreAlwaysScoreable() throws {
        let generator = makeGenerator()
        for potential: Double in [0, 0.5, 1] {
            let deal = try generator.generateDeal(potential: potential, candidatePoolSize: 5, maxAttemptsPerCandidate: 400)
            let total = Self.wordFinder.allPossibleWords(from: deal.allTiles)
                .compactMap(Scorer.points(for:))
                .reduce(0, +)
            XCTAssertGreaterThan(total, 0, "deal at potential \(potential) produced no scoreable words at all")
        }
    }
}
