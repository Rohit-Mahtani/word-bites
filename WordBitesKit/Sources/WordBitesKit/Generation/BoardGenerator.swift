import Foundation

/// Generates deals (11 tiles: 6 singles + 5 doubles) satisfying the hard
/// constraints from the spec (tile counts, vowel total) and the
/// `SolvabilityChecker`'s definition of "not dead," re-rolling the whole
/// deal until both are met.
public struct BoardGenerator: Sendable {
    public enum GenerationError: Error {
        case exceededMaxAttempts
    }

    private let bigramPool: BigramPool
    private let solvabilityChecker: SolvabilityChecker

    public init(bigramPool: BigramPool, solvabilityChecker: SolvabilityChecker) {
        self.bigramPool = bigramPool
        self.solvabilityChecker = solvabilityChecker
    }

    /// Re-rolls the whole deal until tile counts, vowel total (5 or 6 across
    /// all 11 tiles), and the solvability check are all satisfied.
    public func generateDeal(maxAttempts: Int = 1000, rng: inout some RandomNumberGenerator) throws -> Deal {
        for _ in 0..<maxAttempts {
            let deal = generateCandidateDeal(using: &rng)
            if deal.satisfiesHardConstraints, solvabilityChecker.isSolvable(deal) {
                return deal
            }
        }
        throw GenerationError.exceededMaxAttempts
    }

    public func generateDeal(maxAttempts: Int = 1000) throws -> Deal {
        var rng = SystemRandomNumberGenerator()
        return try generateDeal(maxAttempts: maxAttempts, rng: &rng)
    }

    private func generateCandidateDeal(using rng: inout some RandomNumberGenerator) -> Deal {
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
}
