import Foundation

/// Generates deals biased toward high scoring potential rather than pure
/// randomness. At `potential == 0` this behaves exactly like
/// `BoardGenerator` (fully random, still respecting every hard constraint).
/// At `potential == 1` it strongly favors "anchor word" board shapes that
/// produce real high-scoring rounds: the deal is guaranteed to contain every
/// letter of a literal spellable word (e.g. PLANTERS) plus its critical hook
/// letter (e.g. C), so a player can always assemble the anchor word and the
/// large family of related words pro players chain off it, plus extra
/// "hook" letters around it for forming even more.
public struct HighScoreBoardGenerator: Sendable {
    public enum GenerationError: Error {
        case exceededMaxAttempts
    }

    /// A literal word the deal can guarantee is spellable, the one
    /// orientation that spelling assembles in (an 8-letter word fits either
    /// way on this board, but a 9-letter word only fits reading down a
    /// 9-row column, never across an 8-column row), and the extra letters
    /// that make the anchor actually useful: `criticalHookLetter` is a
    /// letter outside the anchor's own spelling that's near-mandatory for
    /// forming the large family of words pro players chain off this anchor
    /// (e.g. C for PLANTERS, T for ALIGNERS/MALIGNERS) and is always
    /// guaranteed as its own single tile; `favoredHookLetters` are
    /// additional letters worth biasing toward when they're known to unlock
    /// further chains, without being mandatory.
    struct AnchorWord: Sendable {
        let letters: [Character]
        let orientation: TileOrientation
        let criticalHookLetter: Character
        let favoredHookLetters: [Character]
    }

    // PLANTERS works either way the board is read; MALIGNERS (9 letters)
    // only fits vertically; ALIGNERS (8 letters, drops the M) is the
    // horizontal fallback for that same letter family. Picked uniformly,
    // so PLANTERS ends up chosen ~50% of the time the anchor path is taken.
    static let anchorWords: [AnchorWord] = [
        AnchorWord(letters: Array("PLANTERS"), orientation: .horizontal, criticalHookLetter: "C", favoredHookLetters: ["G", "D", "K", "O"]),
        AnchorWord(letters: Array("PLANTERS"), orientation: .vertical, criticalHookLetter: "C", favoredHookLetters: ["G", "D", "K", "O"]),
        AnchorWord(letters: Array("ALIGNERS"), orientation: .horizontal, criticalHookLetter: "T", favoredHookLetters: []),
        AnchorWord(letters: Array("MALIGNERS"), orientation: .vertical, criticalHookLetter: "T", favoredHookLetters: [])
    ]

    /// How an anchor word's letters map onto tile slots. One single-tile
    /// slot is always reserved for the critical hook letter — a single tile
    /// has no orientation, so it's always alignable with whichever
    /// direction the anchor word ends up read in, guaranteeing it's never
    /// stranded on the wrong axis. As many anchor letters as fit in the
    /// remaining single slots ride there; any beyond that each get a
    /// dedicated double tile (paired with one hook letter).
    struct AnchorAssignment {
        let singleAnchorLetters: [Character]
        let overflowAnchorLetters: [Character]
        let hookDoublesNeeded: Int
    }

    /// The orientation an overflow anchor-letter double must use: opposite
    /// the anchor's own line direction, so it can contribute just its
    /// anchor letter to that line without forcing its paired hook letter in
    /// too (see `generateAnchorCandidate`).
    static func perpendicularDirection(for anchor: AnchorWord) -> TileOrientation {
        anchor.orientation == .horizontal ? .vertical : .horizontal
    }

    static func anchorAssignment(for anchor: AnchorWord) -> AnchorAssignment {
        let reservedForCritical = 1
        let singleCount = min(anchor.letters.count, Deal.singleTileCount - reservedForCritical)
        let singleAnchorLetters = Array(anchor.letters.prefix(singleCount))
        let overflowAnchorLetters = Array(anchor.letters.suffix(from: singleCount))
        return AnchorAssignment(
            singleAnchorLetters: singleAnchorLetters,
            overflowAnchorLetters: overflowAnchorLetters,
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
    /// full letter set plus its critical hook letter: the anchor's own
    /// letters ride on single tiles (as many as fit) plus one dedicated
    /// double per overflow letter, the critical hook letter always gets its
    /// own single tile, and the remaining doubles are filled from
    /// `hookLetterSource` (occasionally biased toward the anchor's favored
    /// extra letters).
    private func generateAnchorCandidate(using rng: inout some RandomNumberGenerator) -> Deal? {
        guard let anchor = Self.anchorWords.randomElement(using: &rng) else { return nil }
        let assignment = Self.anchorAssignment(for: anchor)
        let anchorLetterSet = Set(anchor.letters)

        let hookBigrams = hookLetterSource.candidateBigrams(
            count: assignment.hookDoublesNeeded, anchorLetters: anchorLetterSet, using: &rng
        )
        guard hookBigrams.count == assignment.hookDoublesNeeded else { return nil }

        let singles = (assignment.singleAnchorLetters + [anchor.criticalHookLetter]).map { SingleTile(letter: $0) }

        // Each overflow anchor letter rides its own double, paired with a
        // sampled hook letter, oriented PERPENDICULAR to the anchor's line.
        // That's the only orientation that lets this double contribute just
        // its anchor letter to the anchor line without also dragging the
        // hook letter into it — a double oriented parallel to the line
        // would force both its letters into that same run together,
        // corrupting the anchor spelling.
        let perpendicular = Self.perpendicularDirection(for: anchor)
        let overflowDoubles = assignment.overflowAnchorLetters.map { anchorLetter -> DoubleTile in
            let hookLetter = sampleHookLetter(favoring: anchor.favoredHookLetters, using: &rng)
            return Bool.random(using: &rng)
                ? DoubleTile(firstLetter: anchorLetter, secondLetter: hookLetter, orientation: perpendicular)
                : DoubleTile(firstLetter: hookLetter, secondLetter: anchorLetter, orientation: perpendicular)
        }

        // Pure hook doubles carry no anchor letters, so their orientation is
        // unconstrained — occasionally biased toward the anchor family's
        // favored extra letters instead of a plain dictionary-frequency bigram.
        let hookDoubles = hookBigrams.map { bigram -> DoubleTile in
            let orientation: TileOrientation = Bool.random(using: &rng) ? .horizontal : .vertical
            if !anchor.favoredHookLetters.isEmpty, Bool.random(using: &rng) {
                let favored = anchor.favoredHookLetters.randomElement(using: &rng)!
                let other = LetterFrequency.sample(using: &rng)
                return Bool.random(using: &rng)
                    ? DoubleTile(firstLetter: favored, secondLetter: other, orientation: orientation)
                    : DoubleTile(firstLetter: other, secondLetter: favored, orientation: orientation)
            }
            return DoubleTile(firstLetter: bigram.first, secondLetter: bigram.second, orientation: orientation)
        }

        return Deal(singleTiles: singles, doubleTiles: (overflowDoubles + hookDoubles).shuffled(using: &rng))
    }

    private func sampleHookLetter(favoring favored: [Character], using rng: inout some RandomNumberGenerator) -> Character {
        if !favored.isEmpty, Bool.random(using: &rng) {
            return favored.randomElement(using: &rng)!
        }
        return LetterFrequency.sample(using: &rng)
    }
}
