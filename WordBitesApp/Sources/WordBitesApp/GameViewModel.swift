import Foundation
import Combine
import WordBitesKit

enum GameMode: Equatable {
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
    @Published private(set) var board = Board()
    @Published private(set) var tiles: [Tile] = []
    @Published private(set) var placements: [UUID: Placement] = [:]
    @Published private(set) var score = 0
    @Published private(set) var timeRemaining = GameViewModel.roundSeconds
    @Published private(set) var roundOver = false
    @Published private(set) var isDealing = true
    @Published private(set) var loadError: String?
    @Published private(set) var scoreToast: ScoreToast?

    @Published private(set) var solverWords: Set<String> = []
    @Published private(set) var isComputingSolverWords = false

    private(set) var foundWords: Set<String> = []

    private var dictionary: WordDictionary?
    private var wordFinder: WordFinder?
    private var generator: BoardGenerator?
    private var loadingTask: Task<Void, Never>?
    private var timer: Timer?
    private var toastQueue: [ScoreToast] = []
    private var toastDismissTask: Task<Void, Never>?

    init() {
        loadingTask = Task { await loadResources() }
    }

    private func loadResources() async {
        do {
            let dictionary = try await Task.detached(priority: .userInitiated) {
                try WordDictionary.loadEnable1()
            }.value
            let bigramPool = await Task.detached(priority: .userInitiated) {
                BigramPool(dictionary: dictionary)
            }.value
            self.dictionary = dictionary
            self.wordFinder = WordFinder(dictionary: dictionary)
            self.generator = BoardGenerator(
                bigramPool: bigramPool,
                solvabilityChecker: SolvabilityChecker(dictionary: dictionary)
            )
        } catch {
            loadError = "Couldn't load the dictionary: \(error.localizedDescription)"
        }
    }

    /// Starts a fresh round in the given mode, waiting for the one-time
    /// dictionary/generator load if it hasn't finished yet.
    func startRound(mode: GameMode) {
        self.mode = mode
        isDealing = true
        timer?.invalidate()
        toastDismissTask?.cancel()
        toastQueue = []
        scoreToast = nil
        solverWords = []

        Task {
            await loadingTask?.value
            guard let generator else { return }
            let deal = try? await Task.detached(priority: .userInitiated) {
                try generator.generateDeal()
            }.value
            guard let deal else { return }
            applyNewDeal(deal)
        }
    }

    private func applyNewDeal(_ deal: Deal) {
        tiles = deal.allTiles
        board = Board()
        placements = [:]
        foundWords = []
        score = 0
        timeRemaining = Self.roundSeconds
        roundOver = false

        let scattered = Self.scatterTiles(tiles)
        for (tileID, placement) in scattered {
            guard let tile = tiles.first(where: { $0.id == tileID }) else { continue }
            board.place(tile, at: placement)
            placements[tileID] = placement
        }

        isDealing = false

        if mode == .timed {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
    }

    private func tick() {
        guard timeRemaining > 0 else { return }
        timeRemaining -= 1
        if timeRemaining == 0 { finishRound() }
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
        if board.place(tile, at: candidate) {
            placements[tileID] = candidate
        } else {
            board.place(tile, at: previous)
        }

        scanForNewWords()
    }

    func placement(for tileID: UUID) -> Placement? { placements[tileID] }

    private func scanForNewWords() {
        var newlyFound: [(String, Int)] = []
        for row in 0..<Board.rowCount {
            scanLine(length: Board.columnCount, newlyFound: &newlyFound) { col in Position(column: col, row: row) }
        }
        for col in 0..<Board.columnCount {
            scanLine(length: Board.rowCount, newlyFound: &newlyFound) { row in Position(column: col, row: row) }
        }
        guard !newlyFound.isEmpty else { return }

        for (word, points) in newlyFound {
            foundWords.insert(word)
            score += points
        }
        enqueueToasts(newlyFound)
        FeedbackPlayer.wordScored()
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

    private func enqueueToasts(_ events: [(String, Int)]) {
        toastQueue.append(contentsOf: events.map { ScoreToast(id: UUID(), word: $0.0, points: $0.1) })
        advanceToastQueueIfNeeded()
    }

    private func advanceToastQueueIfNeeded() {
        guard scoreToast == nil, !toastQueue.isEmpty else { return }
        let next = toastQueue.removeFirst()
        scoreToast = next
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard !Task.isCancelled else { return }
            self?.scoreToast = nil
            self?.advanceToastQueueIfNeeded()
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
