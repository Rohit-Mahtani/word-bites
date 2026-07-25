import XCTest
@testable import WordBitesKit

/// Regression coverage for a real-world report: words the player scores
/// during live play were missing from the post-round solver's word list.
/// Live scoring reads board cells per row/column independently of tile
/// identity, so a double tile's two cells can legitimately land in two
/// different lines (see `WordFinder`'s updated doc comment). This test
/// empirically checks that gap is closed: across many randomly generated
/// and randomly placed boards, every word actually readable on the board
/// must also be discoverable by `WordFinder.allPossibleWords`.
final class LiveScoringSolverConsistencyTests: XCTestCase {
    private static let dictionary: WordDictionary = try! WordDictionary.loadDefault()
    private static let bigramPool = BigramPool(dictionary: dictionary)
    private static let solvabilityChecker = SolvabilityChecker(dictionary: dictionary)
    private static let wordFinder = WordFinder(dictionary: dictionary)
    private static let boardGenerator = BoardGenerator(bigramPool: bigramPool, solvabilityChecker: solvabilityChecker)
    private static let highScoreGenerator = HighScoreBoardGenerator(
        bigramPool: bigramPool,
        solvabilityChecker: solvabilityChecker,
        wordFinder: wordFinder
    )

    func testLiveReadableWordsAreAlwaysFindableByWordFinder() throws {
        for seed in 0..<30 {
            var rng = SeededRNG(seed: UInt64(seed))
            let deal: Deal
            if seed.isMultiple(of: 2) {
                deal = try Self.boardGenerator.generateDeal(rng: &rng)
            } else {
                let potential = Double(seed % 10) / 9.0
                deal = try Self.highScoreGenerator.generateDeal(potential: potential, candidatePoolSize: 3, maxAttemptsPerCandidate: 200)
            }

            let board = Self.scatterAllowingAdjacency(deal.allTiles, rng: &rng)
            let live = Self.liveReadableWords(on: board, dictionary: Self.dictionary)
            let solverWords = Self.wordFinder.allPossibleWords(from: deal.allTiles)

            let missing = live.subtracting(solverWords)
            XCTAssertTrue(missing.isEmpty, "seed \(seed): live-readable words missing from WordFinder: \(missing)")
        }
    }

    /// Places each tile at a random in-bounds origin, respecting its own
    /// fixed orientation, avoiding only literal cell overlap -- deliberately
    /// *not* the strict no-touch halo rule the real deal-time scatter uses.
    /// The no-touch rule guarantees no two tiles are ever adjacent, so a
    /// test built on it would find zero multi-tile runs and pass vacuously.
    /// This mirrors what unconstrained player dragging actually allows
    /// during a round (`GameViewModel.attemptMove` enforces no halo rule).
    private static func scatterAllowingAdjacency(_ tiles: [Tile], rng: inout SeededRNG) -> Board {
        var board = Board()
        for tile in tiles {
            let orientation: TileOrientation
            if case .double(let double) = tile { orientation = double.orientation } else { orientation = .horizontal }
            for _ in 0..<500 {
                let origin = Position(
                    column: Int.random(in: 0..<Board.columnCount, using: &rng),
                    row: Int.random(in: 0..<Board.rowCount, using: &rng)
                )
                let placement = Placement(tileID: tile.id, origin: origin, direction: orientation)
                if board.place(tile, at: placement) { break }
            }
        }
        return board
    }

    /// Reimplements `GameViewModel.scanLine`/`considerCompletedRun`: every
    /// maximal contiguous run of filled cells in each row/column that's a
    /// valid dictionary word of at least the minimum length.
    private static func liveReadableWords(on board: Board, dictionary: WordDictionary) -> Set<String> {
        var found = Set<String>()
        for row in 0..<Board.rowCount {
            scanLine(on: board, length: Board.columnCount, dictionary: dictionary, found: &found) { col in Position(column: col, row: row) }
        }
        for col in 0..<Board.columnCount {
            scanLine(on: board, length: Board.rowCount, dictionary: dictionary, found: &found) { row in Position(column: col, row: row) }
        }
        return found
    }

    private static func scanLine(
        on board: Board,
        length: Int,
        dictionary: WordDictionary,
        found: inout Set<String>,
        position: (Int) -> Position
    ) {
        var current = ""
        for i in 0...length {
            let letter: Character? = i < length ? board.letter(at: position(i)) : nil
            if let letter {
                current.append(letter)
            } else {
                if current.count >= WordDictionary.minimumWordLength, dictionary.isValidWord(current) {
                    found.insert(current)
                }
                current = ""
            }
        }
    }
}
