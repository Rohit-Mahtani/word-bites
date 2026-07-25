import Foundation

/// Generates deals biased toward high scoring potential rather than pure
/// randomness. At `potential == 0` this behaves exactly like
/// `BoardGenerator` (fully random, still respecting every hard constraint).
/// At `potential == 1` it strongly favors "anchor word" board shapes that
/// produce real high-scoring rounds: the deal is guaranteed to contain every
/// letter of a literal spellable word (e.g. PLANTERS), so a player can
/// always assemble that complete word, plus extra "hook" letters around it
/// for forming many more words from the anchor's fragments.
public struct HighScoreBoardGenerator: Sendable {
    public enum GenerationError: Error {
        case exceededMaxAttempts
    }

    /// A literal word the deal can guarantee is spellable, and the one
    /// orientation that spelling assembles in (an 8-letter word fits either
    /// way on this board, but a 9-letter word only fits reading down a
    /// 9-row column, never across an 8-column row).
    struct AnchorWord: Sendable {
        let letters: [Character]
        let orientation: TileOrientation
    }

    // PLANTERS works either way the board is read; MALIGNERS (9 letters)
    // only fits vertically; ALIGNERS (8 letters, drops the M) is the
    // horizontal fallback for that same letter family. Picked uniformly,
    // so PLANTERS ends up chosen ~50% of the time the anchor path is taken.
    static let anchorWords: [AnchorWord] = [
        AnchorWord(letters: Array("PLANTERS"), orientation: .horizontal),
        AnchorWord(letters: Array("PLANTERS"), orientation: .vertical),
        AnchorWord(letters: Array("ALIGNERS"), orientation: .horizontal),
        AnchorWord(letters: Array("MALIGNERS"), orientation: .vertical)
    ]

    /// How an anchor word's letters map onto tile slots: as many letters as
    /// fit ride on their own single tile; any beyond the 6 single-tile slots
    /// each get a dedicated double tile (paired with one hook letter). A
    /// double tile can always contribute just one of its two letters to a
    /// word (see `WordFinder`), so which letter overflows and how its
    /// double is oriented doesn't affect whether the anchor word is still
    /// fully assemblable.
    struct AnchorAssignment {
        let singleAnchorLetters: [Character]
        let overflowAnchorLetters: [Character]
        let hookSinglesNeeded: Int
        let hookDoublesNeeded: Int
    }

    static func anchorAssignment(for anchor: AnchorWord) -> AnchorAssignment {
        let singleCount = min(anchor.letters.count, Deal.singleTileCount)
        let singleAnchorLetters = Array(anchor.letters.prefix(singleCount))
        let overflowAnchorLetters = Array(anchor.letters.suffix(from: singleCount))
        return AnchorAssignment(
            singleAnchorLetters: singleAnchorLetters,
            overflowAnchorLetters: overflowAnchorLetters,
            hookSinglesNeeded: Deal.singleTileCount - singleAnchorLetters.count,
            hookDoublesNeeded: Deal.doubleTileCount - overflowAnchorLetters.count
        )
    }

    private let bigramPool: BigramPool
    private let solvabilityChecker: SolvabilityChecker
    private let wordFinder: WordFinder
    private let hookLetterSource: any HookLetterSource

    public init(
        bigramPool: BigramPool,
        solvabilityChecker: SolvabilityChecker,
        wordFinder: WordFinder,
        hookLetterSource: (any HookLetterSource)? = nil
    ) {
        self.bigramPool = bigramPool
        self.solvabilityChecker = solvabilityChecker
        self.wordFinder = wordFinder
        self.hookLetterSource = hookLetterSource ?? FrequencyHookLetterSource(bigramPool: bigramPool)
    }

    /// Generates a deal. `potential` (clamped to 0...1) controls both how
    /// strongly candidates are biased toward an anchor-word shape and how
    /// many candidates are evaluated (by total possible score) before
    /// keeping the best one — so higher potential costs more time but
    /// produces a better board.
    public func generateDeal(
        potential: Double,
        candidatePoolSize: Int = 15,
        maxAttemptsPerCandidate: Int = 600
    ) throws -> Deal {
        let strength = min(max(potential, 0), 1)
        let candidateCount = max(1, 1 + Int(strength * Double(candidatePoolSize - 1)))

        var best: (deal: Deal, score: Int)?
        for _ in 0..<candidateCount {
            guard let deal = try? generateCandidate(biasStrength: strength, maxAttempts: maxAttemptsPerCandidate) else {
                continue
            }
            let total = totalPossibleScore(for: deal)
            if best == nil || total > best!.score {
                best = (deal, total)
            }
        }
        guard let best else { throw GenerationError.exceededMaxAttempts }
        return best.deal
    }

    private func totalPossibleScore(for deal: Deal) -> Int {
        wordFinder.allPossibleWords(from: deal.allTiles)
            .compactMap { Scorer.points(for: $0) }
            .reduce(0, +)
    }

    private func generateCandidate(biasStrength: Double, maxAttempts: Int) throws -> Deal {
        var rng = SystemRandomNumberGenerator()
        let useAnchor = Double.random(in: 0...1, using: &rng) < biasStrength
        for _ in 0..<maxAttempts {
            guard let deal = useAnchor ? generateAnchorCandidate(using: &rng) : generatePlainCandidate(using: &rng) else { continue }
            if deal.satisfiesHardConstraints, solvabilityChecker.isSolvable(deal) {
                return deal
            }
        }
        throw GenerationError.exceededMaxAttempts
    }

    private func generatePlainCandidate(using rng: inout some RandomNumberGenerator) -> Deal {
        let singles = (0..<Deal.singleTileCount).map { _ in
            SingleTile(letter: LetterFrequency.sample(using: &rng))
        }
        let doubles = (0..<Deal.doubleTileCount).map { _ -> DoubleTile in
            let bigram = bigramPool.sample(using: &rng)
            let orientation: TileOrientation = Bool.random(using: &rng) ? .horizontal : .vertical
            return DoubleTile(firstLetter: bigram.first, secondLetter: bigram.second, orientation: orientation)
        }
        return Deal(singleTiles: singles, doubleTiles: doubles)
    }

    /// Builds a deal guaranteed to contain a randomly-chosen anchor word's
    /// full letter set: the first slice rides on single tiles, any overflow
    /// each rides in its own double tile paired with a hook letter, and the
    /// remaining doubles/singles are filled from `hookLetterSource`.
    private func generateAnchorCandidate(using rng: inout some RandomNumberGenerator) -> Deal? {
        guard let anchor = Self.anchorWords.randomElement(using: &rng) else { return nil }
        let assignment = Self.anchorAssignment(for: anchor)
        let anchorLetterSet = Set(anchor.letters)

        let hookSingles = hookLetterSource.candidateSingleLetters(
            count: assignment.hookSinglesNeeded, anchorLetters: anchorLetterSet, using: &rng
        )
        let hookBigrams = hookLetterSource.candidateBigrams(
            count: assignment.hookDoublesNeeded, anchorLetters: anchorLetterSet, using: &rng
        )
        guard hookSingles.count == assignment.hookSinglesNeeded, hookBigrams.count == assignment.hookDoublesNeeded else {
            return nil
        }

        let singles = (assignment.singleAnchorLetters + hookSingles).map { SingleTile(letter: $0) }

        let overflowDoubles = assignment.overflowAnchorLetters.map { anchorLetter -> DoubleTile in
            let hookLetter = LetterFrequency.sample(using: &rng)
            let orientation: TileOrientation = Bool.random(using: &rng) ? .horizontal : .vertical
            return Bool.random(using: &rng)
                ? DoubleTile(firstLetter: anchorLetter, secondLetter: hookLetter, orientation: orientation)
                : DoubleTile(firstLetter: hookLetter, secondLetter: anchorLetter, orientation: orientation)
        }
        let hookDoubles = hookBigrams.map { bigram -> DoubleTile in
            let orientation: TileOrientation = Bool.random(using: &rng) ? .horizontal : .vertical
            return DoubleTile(firstLetter: bigram.first, secondLetter: bigram.second, orientation: orientation)
        }

        return Deal(singleTiles: singles, doubleTiles: (overflowDoubles + hookDoubles).shuffled(using: &rng))
    }
}
