import Foundation
import WordBitesKit

// Terminal prototype: generates one real deal via WordBitesKit and lets you
// type words against it. Stands in for the SwiftUI board until that exists.
// The 80s timer is checked between prompts, not preemptively while you're
// mid-keystroke — a real UI would need actual input handling to cut you off
// exactly on time.

// WORDBITES_DICTIONARY_PATH lets a local run swap in a personally licensed
// word list (e.g. Collins CSW) instead of the bundled public-domain ENABLE1 —
// never set in CI, never committed, so the public build always uses ENABLE1.
let dictionary: WordDictionary
if let customPath = ProcessInfo.processInfo.environment["WORDBITES_DICTIONARY_PATH"] {
    print("Loading dictionary from \(customPath)...")
    dictionary = try WordDictionary.load(from: URL(fileURLWithPath: customPath))
} else {
    print("Loading dictionary (ENABLE1)...")
    dictionary = try WordDictionary.loadEnable1()
}
let bigramPool = BigramPool(dictionary: dictionary)
let solvabilityChecker = SolvabilityChecker(dictionary: dictionary)
let generator = BoardGenerator(bigramPool: bigramPool, solvabilityChecker: solvabilityChecker)

print("Dealing a board...")
let deal = try generator.generateDeal()

func displayName(for tile: Tile) -> String {
    switch tile {
    case .single(let single):
        return String(single.letter)
    case .double(let double):
        let orientation = double.orientation == .horizontal ? "horizontal" : "vertical"
        return "\(double.text) (\(orientation))"
    }
}

print("\nYour 11 tiles:")
for (index, tile) in deal.allTiles.enumerated() {
    print("  \(index + 1). \(displayName(for: tile))")
}

/// Whether `word` can be spelled by concatenating some ordered subset of
/// `tiles` (each tile used at most once), respecting each tile's fixed
/// letter order. Tiles aren't consumed across guesses — the real game lets
/// you re-form the same tiles into new words all round.
func canForm(_ word: String, from tiles: [Tile]) -> Bool {
    let target = Array(word.uppercased())
    var used = Array(repeating: false, count: tiles.count)

    func search(_ position: Int) -> Bool {
        if position == target.count { return true }
        for i in tiles.indices where !used[i] {
            let letters = tiles[i].letters
            let end = position + letters.count
            guard end <= target.count, Array(target[position..<end]) == letters else { continue }
            used[i] = true
            if search(end) { return true }
            used[i] = false
        }
        return false
    }

    return search(0)
}

let roundSeconds = 80.0
let endTime = Date().addingTimeInterval(roundSeconds)
var score = 0
var foundWords: Set<String> = []

print("\nType a word and press Enter to submit it. Blank line or \"quit\" ends the round early.")
print("Round ends in \(Int(roundSeconds))s.\n")

while Date() < endTime {
    let remaining = max(0, Int(endTime.timeIntervalSinceNow))
    print("[\(remaining)s left, score: \(score)] > ", terminator: "")
    guard let line = readLine(strippingNewline: true) else { break }
    let word = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if word.isEmpty || word.lowercased() == "quit" { break }

    let upper = word.uppercased()
    if foundWords.contains(upper) {
        print("  Already found \"\(word)\".")
        continue
    }
    guard dictionary.isValidWord(upper) else {
        print("  \"\(word)\" isn't in the dictionary.")
        continue
    }
    guard canForm(upper, from: deal.allTiles) else {
        print("  Can't form \"\(word)\" from your tiles.")
        continue
    }
    guard let points = Scorer.points(for: upper) else {
        print("  \"\(word)\" is valid but not scored at this length.")
        continue
    }
    foundWords.insert(upper)
    score += points
    print("  \u{2713} \"\(word)\" \u{2014} +\(points) points")
}

print("\nTime's up! Final score: \(score)")
print("Words found: \(foundWords.sorted().joined(separator: ", "))")
