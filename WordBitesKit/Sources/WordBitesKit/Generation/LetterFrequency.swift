import Foundation

/// Standard English single-letter frequency weights (percentages, unnormalized).
/// Used to weight single-tile letter sampling so boards don't skew toward
/// uniform-random, unplayable letter distributions.
public enum LetterFrequency {
    public static let weights: [Character: Double] = [
        "E": 12.70, "T": 9.06, "A": 8.17, "O": 7.51, "I": 6.97, "N": 6.75,
        "S": 6.33, "H": 6.09, "R": 5.99, "D": 4.25, "L": 4.03, "C": 2.78,
        "U": 2.76, "M": 2.41, "W": 2.36, "F": 2.23, "G": 2.02, "Y": 1.97,
        "P": 1.93, "B": 1.29, "V": 0.98, "K": 0.77, "J": 0.15, "X": 0.15,
        "Q": 0.10, "Z": 0.07
    ]

    public static func sample(using rng: inout some RandomNumberGenerator) -> Character {
        weightedSample(from: weights, using: &rng)
    }
}
