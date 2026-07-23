import Foundation
import WordBitesKit

struct CustomSingleTile: Identifiable {
    let id = UUID()
    var letter: Character?
}

struct CustomDoubleTile: Identifiable {
    let id = UUID()
    var firstLetter: Character?
    var secondLetter: Character?
    var orientation: TileOrientation = .horizontal
}

/// Holds the player's manually-entered board: 6 single letters + 5 double
/// tiles (letters + orientation). Lives once at the app root so it survives
/// navigating back and forth between mode-select and the editor screen.
/// Deliberately has no opinion on whether the result is "good" — no vowel
/// count, no solvability check, nothing — the whole point is the player
/// gets exactly the board they typed in.
@MainActor
final class CustomBoardStore: ObservableObject {
    @Published var isCustomMode = false
    @Published var singles: [CustomSingleTile]
    @Published var doubles: [CustomDoubleTile]

    init() {
        singles = (0..<Deal.singleTileCount).map { _ in CustomSingleTile() }
        doubles = (0..<Deal.doubleTileCount).map { _ in CustomDoubleTile() }
    }

    var filledSingleCount: Int { singles.filter { $0.letter != nil }.count }
    var filledDoubleCount: Int { doubles.filter { $0.firstLetter != nil && $0.secondLetter != nil }.count }

    var isComplete: Bool {
        filledSingleCount == singles.count && filledDoubleCount == doubles.count
    }

    /// Builds a real Deal from whatever's currently filled in — callers
    /// should check `isComplete` first; returns nil if anything's missing.
    func buildDeal() -> Deal? {
        guard isComplete else { return nil }
        let singleTiles = singles.compactMap { tile -> SingleTile? in
            guard let letter = tile.letter else { return nil }
            return SingleTile(letter: letter)
        }
        let doubleTiles = doubles.compactMap { tile -> DoubleTile? in
            guard let first = tile.firstLetter, let second = tile.secondLetter else { return nil }
            return DoubleTile(firstLetter: first, secondLetter: second, orientation: tile.orientation)
        }
        guard singleTiles.count == singles.count, doubleTiles.count == doubles.count else { return nil }
        return Deal(singleTiles: singleTiles, doubleTiles: doubleTiles)
    }
}
