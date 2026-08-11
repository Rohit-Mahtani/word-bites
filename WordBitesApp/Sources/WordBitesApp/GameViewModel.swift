import Foundation
import Combine
import WordBitesKit

enum GameMode: Hashable {
    case timed
    case untimed
}

struct ScoreToast: Identifiable, Equatable {
    let id: UUID
    let word: String
    let points: Int
}

/// Drives one round: dealing tiles, scattering them onto the board with no
/// two touching, handling drag placement, scanning for newly formed words,
/// and running the timer (timed mode only). Owned once at the app root and
/// reused across rounds via `startRound(mode:)` so the dictionary/bigram
/// pool — the slow part — only ever loads once.
@MainActor
final class GameViewModel: ObservableObject {
    static let roundSeconds = 80

    @Published private(set) var mode: GameMode = .timed
    private(set) var boardSource: BoardSource = .random
    @Published private(set) var board = Board()
    @Published private(set) var tiles: [Tile] = []
    @Published private(set) var placements: [UUID: Placement] = [:]
    @Published private(set) var score = 0
    @Published private(set) var timeRemaining = GameViewModel.roundSeconds
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var roundOver = false
    @Published private(set) var isDealing = true
    @Published private(set) var loadError: String?
    @Published private(set) var scoreToast: ScoreToast?

    @Published private(set) var solverWords: Set<String> = []
    @Published private(set) var isComputingSolverWords = false

    private(set) var foundWords: Set<String> = []

    private var dictionary: WordDictionary?
    private var wordFinder: WordFinder?
    private var generator: HighScoreBoardGenerator?
    private var fallbackGenerator: BoardGenerator?
    private var loadingTask: Task<Void, Never>?
    private var dealingTask: Task<Void, Never>?
    private var timer: Timer?
    private var toastDismissTask: Task<Void, Never>?
    private let statsStore: StatsStore

    init(statsStore: StatsStore) {
        self.statsStore = statsStore
        loadingTask = Task { await loadResources() }
    }

    private func loadResources() async {
        do {
            let dictionary = try await Task.detached(priority: .userInitiated) {
                if let customPath = ProcessInfo.processInfo.environment["WORDBITES_DICTIONARY_PATH"] {
                    return try WordDictionary.load(from: URL(fileURLWithPath: customPath))
                }
                return try WordDictionary.loadDefault()
            }.value
            let bigramPool = await Task.detached(priority: .userInitiated) {
                BigramPool(dictionary: dictionary)
            }.value
            let wordFinder = WordFinder(dictionary: dictionary)
            self.dictionary = dictionary
            self.wordFinder = wordFinder
            let solvabilityChecker = SolvabilityChecker(dictionary: dictionary)
            self.generator = HighScoreBoardGenerator(
                bigramPool: bigramPool,
                solvabilityChecker: solvabilityChecker,
                wordFinder: wordFinder
            )
            self.fallbackGenerator = BoardGenerator(bigramPool: bigramPool, solvabilityChecker: solvabilityChecker)
        } catch {
            loadError = "Couldn't load the dictionary: \(error.localizedDescription)"
        }
    }

    /// Starts a fresh round in the given mode, waiting for the one-time
    /// dictionary/generator load if it hasn't finished yet. `scoringPotential`
    /// (0...1) is passed straight to `HighScoreBoardGenerator` — 0 is plain
    /// random, 1 strongly biases toward the high-scoring board archetypes.
    func startRound(mode: GameMode, scoringPotential: Double) {
        self.mode = mode
        self.boardSource = .random
        isDealing = true
        timer?.invalidate()
        toastDismissTask?.cancel()
        scoreToast = nil
        solverWords = []

        // Cancel any deal still being generated from a previous call — without
        // this, calling startRound again quickly (e.g. backing out and picking
        // a new mode before the first deal finishes) could let the stale Task
        // finish later and overwrite the round the player actually asked for.
        dealingTask?.cancel()
        dealingTask = Task {
            await loadingTask?.value
            guard let generator, let fallbackGenerator else { return }
            let deal = await Task.detached(priority: .userInitiated) { () -> Deal? in
                if let deal = try? generator.generateDeal(potential: scoringPotential) { return deal }
                return try? fallbackGenerator.generateDeal()
            }.value
            guard !Task.isCancelled else { return }
            guard let deal else {
                isDealing = false
                loadError = "Couldn't generate a board this time — please try again."
                return
            }
            applyNewDeal(deal)
        }
    }

    /// Starts a round from a fully player-specified board — no generator,
    /// no vowel/solvability checks, exactly the 11 tiles they typed in.
    /// Tile *positions* are still randomized at deal time via the same
    /// no-touching scatter every board uses; only the letters are custom.
    func startRound(mode: GameMode, customDeal: Deal) {
        self.mode = mode
        self.boardSource = .custom
        isDealing = true
        timer?.invalidate()
        toastDismissTask?.cancel()
        scoreToast = nil
        solverWords = []
        dealingTask?.cancel()
        dealingTask = nil
        applyNewDeal(customDeal)
    }

    private func applyNewDeal(_ deal: Deal) {
        tiles = deal.allTiles
        board = Board()
        placements = [:]
        foundWords = []
        score = 0
        timeRemaining = Self.roundSeconds
        elapsedSeconds = 0
        roundOver = false

        let scattered = Self.scatterTiles(tiles)
        for (tileID, placement) in scattered {
            guard let tile = tiles.first(where: { $0.id == tileID }) else { continue }
            board.place(tile, at: placement)
            placements[tileID] = placement
        }

        isDealing = false

        // Runs in both modes: timed counts down to zero and ends the round;
        // untimed just counts up as an elapsed-time stopwatch, with no
        // auto-finish (the round only ends via quit/solver, same as today).
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        switch mode {
        case .timed:
            guard timeRemaining > 0 else { return }
            timeRemaining -= 1
            if timeRemaining == 0 { finishRound() }
        case .untimed:
            elapsedSeconds += 1
        }
    }

    /// Ends the round early (the "Quit Game" action) and moves to the
    /// solver screen, same destination as a timed round running out.
    func quitGame() {
        finishRound()
    }

    private func finishRound() {
        guard !roundOver else { return }
        roundOver = true
        timer?.invalidate()
        timer = nil
        statsStore.record(score: score, wordCount: foundWords.count, category: BoardCategory(mode: mode, source: boardSource))
        computeSolverWords()
    }

    private func computeSolverWords() {
        guard let wordFinder else { return }
        isComputingSolverWords = true
        let currentTiles = tiles
        Task {
            let words = await Task.detached(priority: .userInitiated) {
                wordFinder.allPossibleWords(from: currentTiles)
            }.value
            solverWords = words
            isComputingSolverWords = false
        }
    }

    /// Attempts to move `tileID` so its origin lands at `origin`, keeping
    /// its existing (fixed) orientation. Reverts to its previous placement
    /// if the target is out of bounds or occupied by a different tile.
    /// Every tile always has a placement — tiles start scattered on the
    /// board and are never "unplaced" — so there's always something to
    /// revert to.
    func attemptMove(tileID: UUID, to origin: Position) {
        guard !roundOver,
              let tile = tiles.first(where: { $0.id == tileID }),
              let previous = placements[tileID] else { return }

        board.remove(tile, at: previous)

        let candidate = Placement(tileID: tileID, origin: origin, direction: previous.direction)
        let finalPlacement: Placement
        if board.place(tile, at: candidate) {
            placements[tileID] = candidate
            finalPlacement = candidate
        } else if let nearby = nearestFreePlacement(for: tile, near: origin, direction: previous.direction),
                  board.place(tile, at: nearby) {
            // Dropped on top of another tile (or off the edge) -- rather
            // than snapping all the way back to where the drag started,
            // land on the closest open cell so a slightly-off drop still
            // goes roughly where the player meant it to.
            placements[tileID] = nearby
            finalPlacement = nearby
        } else {
            board.place(tile, at: previous)
            finalPlacement = previous
        }

        // Only lines actually touched by this tile's new position can have
        // a newly-completed word -- a cell that didn't just change occupancy
        // can't produce a different run than it already had. Was scanning
        // all 17 rows+columns on every single drop; on a run of fast,
        // back-to-back drops (rapid word-making, or just moving tiles
        // quickly) that unnecessary work was happening synchronously on the
        // main thread right at the moment of every drop.
        let cells = Board.cells(origin: finalPlacement.origin, cellCount: tile.cellCount, direction: finalPlacement.direction)
        let affectedRows = Set(cells.map { $0.row })
        let affectedColumns = Set(cells.map { $0.column })
        scanForNewWords(affectedRows: affectedRows, affectedColumns: affectedColumns)
    }

    /// Expanding-ring search around `origin` (the attempted drop point) for
    /// the closest cell(s) where `tile` could actually land, respecting its
    /// fixed `direction`. Candidates within each ring are checked in true
    /// Euclidean-distance order so ties within a ring still resolve to the
    /// visually closest spot. Returns `nil` only if the entire board is
    /// full, which can't happen with just 11 tiles on 72 cells.
    private func nearestFreePlacement(for tile: Tile, near origin: Position, direction: TileOrientation) -> Placement? {
        let maxRadius = max(Board.columnCount, Board.rowCount)
        for radius in 1...maxRadius {
            var ring: [Position] = []
            for dc in -radius...radius {
                for dr in -radius...radius {
                    guard max(abs(dc), abs(dr)) == radius else { continue }
                    ring.append(Position(column: origin.column + dc, row: origin.row + dr))
                }
            }
            ring.sort { a, b in
                // Squaring via multiplication, not pow(_:2) -- same result,
                // but pow() is a generic floating-point function with real
                // overhead of its own, called on every comparison of what's
                // already an O(n log n) sort, repeated per ring. This only
                // runs when a drop lands on an occupied cell or off-board
                // (needing this nearest-free-cell search at all), which
                // happens more often the faster/less precisely tiles are
                // dropped -- exactly when it can least afford to be slow.
                let dax = Double(a.column - origin.column), day = Double(a.row - origin.row)
                let dbx = Double(b.column - origin.column), dby = Double(b.row - origin.row)
                let da = dax * dax + day * day
                let db = dbx * dbx + dby * dby
                return da < db
            }
            for candidate in ring where Self.isInBoardBounds(candidate) {
                let placement = Placement(tileID: tile.id, origin: candidate, direction: direction)
                if board.canPlace(tile, at: placement) { return placement }
            }
        }
        return nil
    }

    func placement(for tileID: UUID) -> Placement? { placements[tileID] }

    /// How this round's dealt tiles could be arranged to spell `word` — for
    /// the solver screen's tap-to-reveal popup. `tiles` is stable by the
    /// time the solver screen can show it (the round is already over).
    func arrangement(forWord word: String) -> WordArrangement? {
        wordFinder?.arrangement(forWord: word, tiles: tiles)
    }

    /// Non-mutating check for live drag feedback: could `tileID` actually
    /// land with its origin at `origin` right now? Called on every drag
    /// frame the candidate cell changes, so it's worth being cheap:
    /// `Board.canPlace` already treats a cell occupied by `tile`'s own ID as
    /// compatible (see its own doc comment), so removing the tile from a
    /// scratch copy of the board first can never change the answer -- it
    /// only ever paid for a copy-on-write array copy on every call for
    /// nothing. Checking directly against the live board gives an identical
    /// result with zero allocation. This is the one change from an earlier
    /// "optimize movement" attempt worth keeping on its own: it's pure
    /// logic, touches no gesture code, no rendering, no state architecture
    /// -- provably the same behavior in every case, not just reasoned to be.
    func canPlace(tileID: UUID, at origin: Position) -> Bool {
        guard let tile = tiles.first(where: { $0.id == tileID }),
              let previous = placements[tileID] else { return false }
        return board.canPlace(tile, at: Placement(tileID: tileID, origin: origin, direction: previous.direction))
    }

    private func scanForNewWords(affectedRows: Set<Int>, affectedColumns: Set<Int>) {
        var newlyFound: [(String, Int)] = []
        for row in affectedRows {
            scanLine(length: Board.columnCount, newlyFound: &newlyFound) { col in Position(column: col, row: row) }
        }
        for col in affectedColumns {
            scanLine(length: Board.rowCount, newlyFound: &newlyFound) { row in Position(column: col, row: row) }
        }
        guard !newlyFound.isEmpty else { return }

        for (word, points) in newlyFound {
            foundWords.insert(word)
            score += points
            FeedbackPlayer.wordScored(length: word.count)
        }
        // Only the most recent word is shown — it should replace whatever
        // was up instantly, never wait in a queue behind an earlier one.
        showToast(for: newlyFound[newlyFound.count - 1])
    }

    private func scanLine(length: Int, newlyFound: inout [(String, Int)], position: (Int) -> Position) {
        var current = ""
        for i in 0...length {
            let letter: Character? = i < length ? board.letter(at: position(i)) : nil
            if let letter {
                current.append(letter)
            } else {
                considerCompletedRun(current, newlyFound: &newlyFound)
                current = ""
            }
        }
    }

    private func considerCompletedRun(_ run: String, newlyFound: inout [(String, Int)]) {
        guard run.count >= WordDictionary.minimumWordLength else { return }
        guard let dictionary, dictionary.isValidWord(run) else { return }
        guard !foundWords.contains(run) else { return }
        guard let points = Scorer.points(for: run) else { return }
        newlyFound.append((run, points))
    }

    /// Instantly swaps in the new word — never queues behind a previous
    /// one, so back-to-back words each replace the display immediately.
    private func showToast(for event: (word: String, points: Int)) {
        toastDismissTask?.cancel()
        scoreToast = ScoreToast(id: UUID(), word: event.word, points: event.points)
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard !Task.isCancelled else { return }
            self?.scoreToast = nil
        }
    }

    /// Scatters `tileList` onto the board so no two tiles' cells are even
    /// diagonally adjacent, falling back to a footprint-only (no overlap)
    /// placement in the rare case that can't be satisfied.
    static func scatterTiles(_ tileList: [Tile]) -> [UUID: Placement] {
        for _ in 0..<150 {
            var footprint = Set<Position>()
            var placements: [UUID: Placement] = [:]
            var ok = true
            for tile in tileList.shuffled() {
                let orientation: TileOrientation
                if case .double(let d) = tile { orientation = d.orientation } else { orientation = .horizontal }
                var placed = false
                for _ in 0..<300 {
                    let origin = Position(
                        column: Int.random(in: 0..<Board.columnCount),
                        row: Int.random(in: 0..<Board.rowCount)
                    )
                    let cells = Board.cells(origin: origin, cellCount: tile.cellCount, direction: orientation)
                    guard cells.allSatisfy(isInBoardBounds) else { continue }
                    let halo = haloPositions(for: cells)
                    guard !halo.contains(where: footprint.contains) else { continue }
                    footprint.formUnion(cells)
                    placements[tile.id] = Placement(tileID: tile.id, origin: origin, direction: orientation)
                    placed = true
                    break
                }
                if !placed { ok = false; break }
            }
            if ok { return placements }
        }
        return scatterTilesRelaxed(tileList)
    }

    private static func scatterTilesRelaxed(_ tileList: [Tile]) -> [UUID: Placement] {
        var board = Board()
        var placements: [UUID: Placement] = [:]
        for tile in tileList {
            let orientation: TileOrientation
            if case .double(let d) = tile { orientation = d.orientation } else { orientation = .horizontal }
            for _ in 0..<500 {
                let origin = Position(
                    column: Int.random(in: 0..<Board.columnCount),
                    row: Int.random(in: 0..<Board.rowCount)
                )
                let placement = Placement(tileID: tile.id, origin: origin, direction: orientation)
                if board.place(tile, at: placement) {
                    placements[tile.id] = placement
                    break
                }
            }
        }
        return placements
    }

    private static func isInBoardBounds(_ position: Position) -> Bool {
        position.column >= 0 && position.column < Board.columnCount &&
        position.row >= 0 && position.row < Board.rowCount
    }

    private static func haloPositions(for cells: [Position]) -> Set<Position> {
        var result = Set<Position>()
        for cell in cells {
            for dr in -1...1 {
                for dc in -1...1 {
                    let p = Position(column: cell.column + dc, row: cell.row + dr)
                    if isInBoardBounds(p) { result.insert(p) }
                }
            }
        }
        return result
    }
}
