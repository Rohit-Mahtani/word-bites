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

/// Identifies one of the 16 letter slots (6 singles + 5 doubles x 2) in tab
/// order, for auto-advancing focus as each is filled in.
enum CustomBoardFocusField: Hashable {
    case single(Int)
    case doubleFirst(Int)
    case doubleSecond(Int)
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

    /// All 16 letter slots in tab order: every single, then each double's
    /// first letter then second letter, in the order they're declared.
    private var orderedFields: [CustomBoardFocusField] {
        var fields = singles.indices.map { CustomBoardFocusField.single($0) }
        for index in doubles.indices {
            fields.append(.doubleFirst(index))
            fields.append(.doubleSecond(index))
        }
        return fields
    }

    private func letter(at field: CustomBoardFocusField) -> Character? {
        switch field {
        case .single(let index): return singles[index].letter
        case .doubleFirst(let index): return doubles[index].firstLetter
        case .doubleSecond(let index): return doubles[index].secondLetter
        }
    }

    /// The next field after `field` (wrapping around) that's still empty,
    /// or nil if every slot is already filled.
    func nextEmptyField(after field: CustomBoardFocusField) -> CustomBoardFocusField? {
        let fields = orderedFields
        guard let index = fields.firstIndex(of: field) else { return nil }
        for offset in 1...fields.count {
            let candidate = fields[(index + offset) % fields.count]
            if letter(at: candidate) == nil { return candidate }
        }
        return nil
    }
}
