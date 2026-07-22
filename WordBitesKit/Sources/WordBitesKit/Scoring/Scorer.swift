import Foundation

/// Confirmed exact scoring values from the real app. Lengths outside this
/// table (including 2-letter words) are not scored in v1.
public enum Scorer {
    private static let pointsByLength: [Int: Int] = [
        3: 100,
        4: 400,
        5: 800,
        6: 1400,
        7: 1800,
        8: 2200,
        9: 2600
    ]

    public static func points(forLength length: Int) -> Int? {
        pointsByLength[length]
    }

    public static func points(for word: String) -> Int? {
        points(forLength: word.count)
    }
}
