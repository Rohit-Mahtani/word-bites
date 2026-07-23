import Foundation

/// Generates deals biased toward high scoring potential rather than pure
/// randomness. At `potential == 0` this behaves exactly like
/// `BoardGenerator` (fully random, still respecting every hard constraint).
/// At `potential == 1` it strongly favors the "anchor + disconnected hook
/// letters" board shapes that produce real high-scoring rounds — an anchor
/// consonant (C or T) paired with several other single letters that each
/// support many common suffix hooks (-ERS, -INGS, -LTERS, -NTERS, ...)
/// instead of being pre-combined into double tiles with each other.
public struct HighScoreBoardGenerator: Sendable {
    public enum GenerationError: Error {
        case exceededMaxAttempts
    }

    private struct Archetype {
        let anchor: Character
        let extras: [Character]
    }

    // "Planters" (C-anchor) and "maligners" (T-anchor) — see project notes.
    private static let archetypes: [Archetype] = [
        Archetype(anchor: "C", extras: ["G", "I", "K", "D", "O"]),
        Archetype(anchor: "T", extras: ["C", "O", "H", "D", "K"])
    ]

    private let bigramPool: BigramPool
    private let solvabilityChecker: SolvabilityChecker
    private let wordFinder: WordFinder

    public init(bigramPool: BigramPool, solvabilityChecker: SolvabilityChecker, wordFinder: WordFinder) {
        self.bigramPool = bigramPool
        self.solvabilityChecker = solvabilityChecker
        self.wordFinder = wordFinder
    }

    /// Generates a deal. `potential` (clamped to 0...1) controls both how
    /// strongly candidates are biased toward the archetype shapes and how
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
        let useArchetype = Double.random(in: 0...1, using: &rng) < biasStrength
        for _ in 0..<maxAttempts {
            let deal = useArchetype ? generateArchetypeCandidate(using: &rng) : generatePlainCandidate(using: &rng)
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

    /// Forces the anchor + as many extra hook letters as fit into the 6
    /// single-tile slots, filling any remaining slots normally. Doubles are
    /// still sampled from the ordinary bigram pool, but reject a pairing
    /// that would fuse two of the forced hook letters together — the whole
    /// point of the archetype is that those letters stay independently
    /// playable, not pre-combined into one immovable tile.
    private func generateArchetypeCandidate(using rng: inout some RandomNumberGenerator) -> Deal {
        let archetype = Self.archetypes.randomElement(using: &rng)!
        let forced = Array(([archetype.anchor] + archetype.extras).prefix(Deal.singleTileCount))
        var singleLetters = forced
        while singleLetters.count < Deal.singleTileCount {
            singleLetters.append(LetterFrequency.sample(using: &rng))
        }
        let singles = singleLetters.map { SingleTile(letter: $0) }

        let forcedSet = Set(forced)
        let doubles = (0..<Deal.doubleTileCount).map { _ -> DoubleTile in
            var bigram = bigramPool.sample(using: &rng)
            var guardCount = 0
            while forcedSet.contains(bigram.first), forcedSet.contains(bigram.second), guardCount < 50 {
                bigram = bigramPool.sample(using: &rng)
                guardCount += 1
            }
            let orientation: TileOrientation = Bool.random(using: &rng) ? .horizontal : .vertical
            return DoubleTile(firstLetter: bigram.first, secondLetter: bigram.second, orientation: orientation)
        }
        return Deal(singleTiles: singles, doubleTiles: doubles)
    }
}
