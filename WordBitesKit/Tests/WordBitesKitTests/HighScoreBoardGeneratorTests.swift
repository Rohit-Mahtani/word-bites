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
    /// singles + overflow doubles (as a set -- which letters land on which
    /// side is randomized, so order isn't preserved), exactly one
    /// single-tile slot is left over (reserved for the critical hook
    /// letter), and both slot counts fit the deal's fixed tile counts
    /// (6 singles, 5 doubles) with room for hooks.
    func testAnchorAssignmentCoversEveryAnchorLetterExactlyOnce() {
        var rng = SystemRandomNumberGenerator()
        for anchor in HighScoreBoardGenerator.anchorWords {
            let assignment = HighScoreBoardGenerator.anchorAssignment(for: anchor, using: &rng)
            XCTAssertEqual(
                (assignment.singleAnchorLetters + assignment.overflowAnchorLetters).sorted(),
                anchor.letters.sorted(),
                "singles + overflow should together be exactly \(String(anchor.letters))'s letters"
            )
            XCTAssertEqual(
                assignment.singleAnchorLetters.count + 1, Deal.singleTileCount,
                "exactly one single-tile slot should be left over for the critical hook letter"
            )
            XCTAssertEqual(assignment.overflowAnchorLetters.count + assignment.hookDoublesNeeded, Deal.doubleTileCount)
            XCTAssertLessThanOrEqual(assignment.overflowAnchorLetters.count, Deal.doubleTileCount)
        }
    }

    /// Which letters land on singles vs. overflow doubles should actually
    /// vary from call to call -- this is the behavior change from always
    /// picking the same fixed prefix (e.g. PLANTERS always used to put
    /// E, R, S on doubles every single time, purely because of their
    /// position in the word).
    func testAnchorAssignmentVariesWhichLettersAreSingles() {
        var rng = SystemRandomNumberGenerator()
        let anchor = HighScoreBoardGenerator.anchorWords[0]
        var seenSingleSets = Set<Set<Character>>()
        for _ in 0..<40 {
            let assignment = HighScoreBoardGenerator.anchorAssignment(for: anchor, using: &rng)
            seenSingleSets.insert(Set(assignment.singleAnchorLetters))
        }
        XCTAssertGreaterThan(seenSingleSets.count, 1, "should not always pick the same 5 letters as singles")
    }

    /// The critical hook letter (e.g. C for PLANTERS, T for ALIGNERS/
    /// MALIGNERS) must always land on its own single tile -- never dropped,
    /// and never fused into a double, since a single tile is the only slot
    /// with no orientation constraint at all.
    func testCriticalHookLetterAlwaysLandsOnItsOwnSingleTile() throws {
        let generator = makeGenerator()
        for _ in 0..<8 {
            let deal = try generator.generateDeal(potential: 1, candidatePoolSize: 3, maxAttemptsPerCandidate: 400)
            let allLetters = deal.allTiles.flatMap(\.letters)
            let matchingAnchors = HighScoreBoardGenerator.anchorWords.filter { containsFullLetterSet($0.letters, in: allLetters) }
            XCTAssertFalse(matchingAnchors.isEmpty)
            let criticalLetters = Set(matchingAnchors.map(\.criticalHookLetter))
            let hasCriticalSingle = deal.singleTiles.contains { criticalLetters.contains($0.letter) }
            XCTAssertTrue(hasCriticalSingle, "expected one of \(criticalLetters) as its own single tile")
        }
    }

    /// Whitebox, deterministic: the perpendicular direction used for
    /// overflow anchor-letter doubles is always the opposite of the
    /// anchor's own line direction. (Verifying this end-to-end from a
    /// generated deal's tile orientations would be flaky -- a coincidental
    /// hook letter can randomly match an overflow letter too, e.g. a hook
    /// double that happens to contain an R when PLANTERS' own overflow
    /// letters are E/R/S -- so this checks the underlying rule directly
    /// instead. `testAnchorWordIsDiscoverableByWordFinder` below is the
    /// true end-to-end proof that the orientation is actually correct in
    /// practice: if it were wrong, the anchor word wouldn't be discoverable.)
    func testPerpendicularDirectionIsAlwaysOppositeTheAnchorsOrientation() {
        for anchor in HighScoreBoardGenerator.anchorWords {
            XCTAssertNotEqual(HighScoreBoardGenerator.perpendicularDirection(for: anchor), anchor.orientation)
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

    func testDoubleTilesNeverHaveTheSameLetterTwice() throws {
        let generator = makeGenerator()
        for potential: Double in [0, 0.3, 0.6, 0.9, 1] {
            for _ in 0..<5 {
                let deal = try generator.generateDeal(potential: potential, candidatePoolSize: 3, maxAttemptsPerCandidate: 400)
                for double in deal.doubleTiles {
                    XCTAssertNotEqual(
                        double.firstLetter, double.secondLetter,
                        "potential \(potential) produced a double tile with the same letter twice"
                    )
                }
            }
        }
    }

    /// The REAL guarantee below max potential is that the deliberate bias
    /// pool never includes the critical hook letter (see
    /// `testHookBiasPoolNeverIncludesTheCriticalLetter`, which checks that
    /// directly and deterministically). An earlier version of this test
    /// tried to also check, empirically, that a generated deal's singles
    /// could never coincidentally match some anchor's full signature (5 of
    /// its own letters + its critical hook letter) -- but that's not
    /// actually guaranteed by design, and checking every deal against every
    /// anchor made it a real (if rare) false positive: PLANTERS and
    /// ALIGNERS/MALIGNERS share several letters (L, A, N, E, R, S), and T is
    /// both a completely ordinary PLANTERS letter AND ALIGNERS/MALIGNERS'
    /// own critical hook letter. A PLANTERS-biased deal can perfectly
    /// legitimately end up with singles that happen to also satisfy
    /// ALIGNERS' structural pattern, with zero relation to ALIGNERS' own
    /// (correctly-guarded) bias mechanism ever having fired. That's benign
    /// letter overlap between related words, not a broken guarantee, so
    /// there's nothing meaningful left to test here beyond what
    /// `testHookBiasPoolNeverIncludesTheCriticalLetter` already covers.

    /// Whitebox: an anchor's bias pool (what `generateHookBiasedCandidate`
    /// deliberately draws from) never includes its own critical hook letter
    /// -- that's what keeps the full guarantee combo out of reach below max
    /// potential. (A coincidental critical letter can still land in one of
    /// the deal's *non-biased* fallback slots, same as any other letter can
    /// by chance -- only the deliberate bias excludes it, which is the
    /// actual guarantee, so this checks the pool directly rather than
    /// asserting the letter never appears anywhere in a generated deal.)
    func testHookBiasPoolNeverIncludesTheCriticalLetter() {
        for anchor in HighScoreBoardGenerator.anchorWords {
            let biasPool = anchor.letters + anchor.favoredHookLetters
            XCTAssertFalse(biasPool.contains(anchor.criticalHookLetter))
        }
    }

    /// The number of an anchor family's pool letters deliberately biased
    /// into the deal's singles should scale up with strength.
    func testHookBiasedCandidateScalesWithStrength() {
        let generator = makeGenerator()
        for anchor in HighScoreBoardGenerator.anchorWords {
            var lowHits = 0
            var highHits = 0
            let biasPool = Set(anchor.letters + anchor.favoredHookLetters)
            for seed in 0..<25 {
                var lowRng = SeededRNG(seed: UInt64(seed))
                var highRng = SeededRNG(seed: UInt64(seed))
                if let lowDeal = generator.generateHookBiasedCandidate(strength: 0.1, using: &lowRng) {
                    lowHits += lowDeal.singleTiles.filter { biasPool.contains($0.letter) }.count
                }
                if let highDeal = generator.generateHookBiasedCandidate(strength: 0.9, using: &highRng) {
                    highHits += highDeal.singleTiles.filter { biasPool.contains($0.letter) }.count
                }
            }
            XCTAssertGreaterThan(highHits, lowHits, "higher strength should bias in more of the anchor family's letters on average")
        }
    }
}
