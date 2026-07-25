import XCTest
@testable import WordBitesKit

final class HighScoreBoardGeneratorTests: XCTestCase {
    static let dictionary: WordDictionary = try! WordDictionary.loadDefault()
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

    private func containsFullLetterSet(_ letters: [Character], in pool: [Character]) -> Bool {
        var counts = pool.reduce(into: [Character: Int]()) { $0[$1, default: 0] += 1 }
        for letter in letters {
            guard let count = counts[letter], count > 0 else { return false }
            counts[letter] = count - 1
        }
        return true
    }

    func testZeroPotentialStillSatisfiesHardConstraintsAndSolvability() throws {
        let generator = makeGenerator()
        for _ in 0..<5 {
            let deal = try generator.generateDeal(potential: 0, candidatePoolSize: 1)
            XCTAssertTrue(deal.satisfiesHardConstraints)
            XCTAssertTrue(Self.solvabilityChecker.isSolvable(deal))
        }
    }

    /// Whitebox: every anchor word's letters are covered exactly once by
    /// singles + overflow doubles, and both slot counts fit the deal's
    /// fixed tile counts (6 singles, 5 doubles) with room left for hooks.
    func testAnchorAssignmentCoversEveryAnchorLetterExactlyOnce() {
        for anchor in HighScoreBoardGenerator.anchorWords {
            let assignment = HighScoreBoardGenerator.anchorAssignment(for: anchor)
            XCTAssertEqual(
                assignment.singleAnchorLetters + assignment.overflowAnchorLetters,
                anchor.letters,
                "singles + overflow should reconstruct \(String(anchor.letters)) exactly, in order"
            )
            XCTAssertEqual(assignment.singleAnchorLetters.count + assignment.hookSinglesNeeded, Deal.singleTileCount)
            XCTAssertEqual(assignment.overflowAnchorLetters.count + assignment.hookDoublesNeeded, Deal.doubleTileCount)
            XCTAssertLessThanOrEqual(assignment.singleAnchorLetters.count, Deal.singleTileCount)
            XCTAssertLessThanOrEqual(assignment.overflowAnchorLetters.count, Deal.doubleTileCount)
        }
    }

    /// Black-box: at potential 1, the deal's full 16-letter multiset always
    /// contains at least one anchor word's complete letter set.
    func testHighPotentialDealsContainAnAnchorWordsFullLetterSet() throws {
        let generator = makeGenerator()
        for _ in 0..<8 {
            let deal = try generator.generateDeal(potential: 1, candidatePoolSize: 3, maxAttemptsPerCandidate: 400)
            let allLetters = deal.allTiles.flatMap(\.letters)
            let matchesAnAnchor = HighScoreBoardGenerator.anchorWords.contains {
                containsFullLetterSet($0.letters, in: allLetters)
            }
            XCTAssertTrue(matchesAnAnchor, "expected the deal's letters to fully contain an anchor word, got \(allLetters)")
        }
    }

    /// Integration: for a potential-1 deal, at least one anchor word whose
    /// full letter set is present must actually be discoverable by
    /// WordFinder — proving an anchor word isn't just physically present as
    /// loose letters but genuinely assemblable and solver-discoverable
    /// (this only holds now that WordFinder understands partial double-tile
    /// usage). Checking *any* matching anchor rather than just the first is
    /// deliberate: incidental hook letters can coincidentally satisfy more
    /// than one anchor's raw letter multiset (e.g. an ALIGNERS deal whose
    /// random hook doubles happen to also include a P and a T), but only
    /// the anchor the generator actually built around has its letters
    /// isolated onto dedicated tiles — a coincidental match on a *different*
    /// anchor's multiset isn't guaranteed to be tile-reconstructable, and
    /// asserting on it specifically would make this test flaky.
    func testAnchorWordIsDiscoverableByWordFinder() throws {
        let generator = makeGenerator()
        for _ in 0..<8 {
            let deal = try generator.generateDeal(potential: 1, candidatePoolSize: 3, maxAttemptsPerCandidate: 400)
            let allLetters = deal.allTiles.flatMap(\.letters)
            let matchingAnchors = HighScoreBoardGenerator.anchorWords.filter { containsFullLetterSet($0.letters, in: allLetters) }
            XCTAssertFalse(matchingAnchors.isEmpty, "deal at potential 1 didn't contain any anchor word's full letter set")

            let words = Self.wordFinder.allPossibleWords(from: deal.allTiles)
            let discoverableSpellings = matchingAnchors.map { String($0.letters) }
            XCTAssertTrue(
                discoverableSpellings.contains(where: words.contains),
                "expected one of \(Set(discoverableSpellings)) to be discoverable by WordFinder from its own generated deal"
            )
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
