import Foundation

/// Where a round's tiles came from — combined with `GameMode` to decide
/// which high-score bucket a finished round counts toward.
enum BoardSource: Sendable {
    case random
    case custom
}

/// The four independently-tracked high-score buckets: every combination of
/// mode and board source, since the UI lets them be picked independently.
enum BoardCategory: String, CaseIterable, Sendable {
    case timedRandom
    case timedCustom
    case untimedRandom
    case untimedCustom

    init(mode: GameMode, source: BoardSource) {
        switch (mode, source) {
        case (.timed, .random): self = .timedRandom
        case (.timed, .custom): self = .timedCustom
        case (.untimed, .random): self = .untimedRandom
        case (.untimed, .custom): self = .untimedCustom
        }
    }

    var displayName: String {
        switch self {
        case .timedRandom: return "Timed · Random"
        case .timedCustom: return "Timed · Custom"
        case .untimedRandom: return "Untimed · Random"
        case .untimedCustom: return "Untimed · Custom"
        }
    }
}

/// Persisted best-ever score and word count per `BoardCategory`, shared
/// between the game (which records new bests when a round ends) and the
/// welcome screen's stats button.
@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var highScores: [BoardCategory: Int] = [:]
    @Published private(set) var highWordCounts: [BoardCategory: Int] = [:]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for category in BoardCategory.allCases {
            highScores[category] = defaults.integer(forKey: Self.scoreKey(for: category))
            highWordCounts[category] = defaults.integer(forKey: Self.wordCountKey(for: category))
        }
    }

    func highScore(for category: BoardCategory) -> Int {
        highScores[category] ?? 0
    }

    func highWordCount(for category: BoardCategory) -> Int {
        highWordCounts[category] ?? 0
    }

    func record(score: Int, wordCount: Int, category: BoardCategory) {
        if score > highScore(for: category) {
            highScores[category] = score
            defaults.set(score, forKey: Self.scoreKey(for: category))
        }
        if wordCount > highWordCount(for: category) {
            highWordCounts[category] = wordCount
            defaults.set(wordCount, forKey: Self.wordCountKey(for: category))
        }
    }

    private static func scoreKey(for category: BoardCategory) -> String {
        "wordbites.highScore.\(category.rawValue)"
    }

    private static func wordCountKey(for category: BoardCategory) -> String {
        "wordbites.highWordCount.\(category.rawValue)"
    }
}
