import Foundation

/// Persisted best-ever score and word count, shared between the game (which
/// records new bests when a round ends) and the welcome screen's stats button.
@MainActor
final class StatsStore: ObservableObject {
    private enum Keys {
        static let highScore = "wordbites.highScore"
        static let highWordCount = "wordbites.highWordCount"
    }

    @Published private(set) var highScore: Int
    @Published private(set) var highWordCount: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        highScore = defaults.integer(forKey: Keys.highScore)
        highWordCount = defaults.integer(forKey: Keys.highWordCount)
    }

    func record(score: Int, wordCount: Int) {
        if score > highScore {
            highScore = score
            defaults.set(score, forKey: Keys.highScore)
        }
        if wordCount > highWordCount {
            highWordCount = wordCount
            defaults.set(wordCount, forKey: Keys.highWordCount)
        }
    }
}
