import Foundation

/// One physical tile's contribution to a word, in reading order, as
/// reconstructed by `WordFinder.arrangement(forWord:tiles:)`. Mirrors the
/// same per-tile combinatorics as `Tile.extensions(forLineDirection:)`: a
/// double tile aligned with the word's own direction contributes both
/// letters as two consecutive slots (`doubleInline`), while a double tile
/// perpendicular to the word can only ever contribute one of its two
/// letters — the other is still physically attached to it on the board, so
/// it's carried along for display even though it's not part of the word
/// (`doublePerpendicular`).
public enum WordArrangementSlot: Sendable, Equatable {
    case single(Character)
    case doublePerpendicular(usedLetter: Character, otherLetter: Character, usedIsFirst: Bool)
    case doubleInline(letter: Character, isFirstOfPair: Bool)

    /// The letter this slot actually contributes to the word.
    public var usedLetter: Character {
        switch self {
        case .single(let letter): return letter
        case .doublePerpendicular(let used, _, _): return used
        case .doubleInline(let letter, _): return letter
        }
    }
}

/// One way to physically arrange a tile set's tiles, in a straight line, to
/// spell a specific word — the same set of tiles the round dealt, shown in
/// their fixed reading order, for the solver screen's "how would this have
/// been arranged" popup. `direction` is the line this particular
/// arrangement was found along (a word findable both ways only reports
/// whichever `arrangement(forWord:tiles:)` tries first) — callers displaying
/// this should lay it out to match, not always as one fixed orientation.
public struct WordArrangement: Sendable, Equatable {
    public let slots: [WordArrangementSlot]
    public let direction: TileOrientation
}

/// Finds every valid word a tile set can produce, for the post-round solver
/// screen. Unlike `SolvabilityChecker` (which stops at the first word that
/// uses a given tile), this exhaustively collects every distinct match —
/// same trie-pruned search shape, just without the early exit.
public struct WordFinder: Sendable {
    private let dictionary: WordDictionary

    public init(dictionary: WordDictionary) {
        self.dictionary = dictionary
    }

    /// All distinct valid words (3-9 letters) formable by concatenating some
    /// ordered subset of `tiles`, each tile used at most once per word, in a
    /// way that's actually assemblable on the physical board. A word is
    /// always read along one straight line (a row or a column), so this
    /// runs the search once per line direction and unions the results: in
    /// the horizontal pass, a horizontal double tile contributes both its
    /// letters together (its two cells are already adjacent in that row —
    /// there's no way to use one and not the other) while a vertical double
    /// can only ever have one of its two cells actually sit in that row (the
    /// other is in an adjacent row), so it contributes either letter alone,
    /// never both — and vice versa for the vertical pass. Each pass is also
    /// capped at that direction's own longest possible line (the board's
    /// width for horizontal, its height for vertical) — a word longer than a
    /// row can hold could otherwise get "found" there by stitching together
    /// single letters pulled from several different vertical doubles that
    /// are actually scattered across different rows, which can never
    /// physically fit in one row.
    public func allPossibleWords(from tiles: [Tile]) -> Set<String> {
        var found = Set<String>()
        for direction in [TileOrientation.horizontal, .vertical] {
            var used = Array(repeating: false, count: tiles.count)
            search(tiles: tiles, direction: direction, used: &used, current: "", found: &found)
        }
        return found
    }

    private func search(
        tiles: [Tile],
        direction: TileOrientation,
        used: inout [Bool],
        current: String,
        found: inout Set<String>
    ) {
        if current.count >= WordDictionary.minimumWordLength, dictionary.isValidWord(current) {
            found.insert(current)
        }
        let limit = SolvabilityChecker.maxWordLength(for: direction)
        guard current.count < limit else { return }

        for i in tiles.indices where !used[i] {
            used[i] = true
            for extension_ in tiles[i].extensions(forLineDirection: direction) {
                let candidate = current + extension_
                guard candidate.count <= limit, dictionary.hasPrefix(candidate) else { continue }
                search(tiles: tiles, direction: direction, used: &used, current: candidate, found: &found)
            }
            used[i] = false
        }
    }

    /// Reconstructs one valid physical arrangement of `tiles` that spells
    /// `word` — the same combinatorics `allPossibleWords` used to find it in
    /// the first place, just targeted at one specific word instead of
    /// exhaustively enumerating every match. Tries the horizontal line
    /// direction first, then vertical; returns whichever succeeds first, or
    /// `nil` if `word` isn't actually formable from `tiles` (shouldn't
    /// happen for a word this same `WordFinder` reported via
    /// `allPossibleWords`, since it's the identical per-tile logic).
    public func arrangement(forWord word: String, tiles: [Tile]) -> WordArrangement? {
        let target = word.uppercased()
        for direction in [TileOrientation.horizontal, .vertical] {
            guard target.count <= SolvabilityChecker.maxWordLength(for: direction) else { continue }
            var used = Array(repeating: false, count: tiles.count)
            var slots: [WordArrangementSlot] = []
            if matchArrangement(remaining: Substring(target), tiles: tiles, direction: direction, used: &used, slots: &slots) {
                return WordArrangement(slots: slots, direction: direction)
            }
        }
        return nil
    }

    private func matchArrangement(
        remaining: Substring,
        tiles: [Tile],
        direction: TileOrientation,
        used: inout [Bool],
        slots: inout [WordArrangementSlot]
    ) -> Bool {
        if remaining.isEmpty { return true }

        for i in tiles.indices where !used[i] {
            used[i] = true
            for extension_ in tiles[i].extensions(forLineDirection: direction) {
                guard remaining.hasPrefix(extension_) else { continue }
                let addedSlots = Self.slots(for: tiles[i], usedExtension: extension_, direction: direction)
                slots.append(contentsOf: addedSlots)
                if matchArrangement(
                    remaining: remaining.dropFirst(extension_.count),
                    tiles: tiles,
                    direction: direction,
                    used: &used,
                    slots: &slots
                ) {
                    return true
                }
                slots.removeLast(addedSlots.count)
            }
            used[i] = false
        }
        return false
    }

    private static func slots(for tile: Tile, usedExtension: String, direction: TileOrientation) -> [WordArrangementSlot] {
        switch tile {
        case .single(let single):
            return [.single(single.letter)]
        case .double(let double):
            if double.orientation == direction {
                return [
                    .doubleInline(letter: double.firstLetter, isFirstOfPair: true),
                    .doubleInline(letter: double.secondLetter, isFirstOfPair: false)
                ]
            }
            let usedIsFirst = usedExtension == String(double.firstLetter)
            let used = usedIsFirst ? double.firstLetter : double.secondLetter
            let other = usedIsFirst ? double.secondLetter : double.firstLetter
            return [.doublePerpendicular(usedLetter: used, otherLetter: other, usedIsFirst: usedIsFirst)]
        }
    }
}
