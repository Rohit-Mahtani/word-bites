import Foundation

/// Single-letter frequency weights (percentages, unnormalized), empirically
/// measured from actual generated Word Bites boards -- not generic English
/// text frequency. This is deliberately flatter than English prose (e.g. no
/// single letter dominates the way E does in text) since a board needs a
/// broad, playable letter spread rather than to mirror written language.
/// Used to weight single-tile letter sampling so boards don't skew toward
/// uniform-random, unplayable letter distributions.
public enum LetterFrequency {
    public static let weights: [Character: Double] = [
        "A": 6.367, "B": 3.3708, "C": 4.3071, "D": 4.3695, "E": 8.6142,
        "F": 1.4981, "G": 3.8702, "H": 4.0574, "I": 7.3658, "J": 0.062422,
        "K": 1.2484, "L": 5.0562, "M": 3.9326, "N": 6.1174, "O": 5.3059,
        "P": 3.6205, "Q": 0.062422, "R": 5.9925, "S": 6.4919, "T": 6.1798,
        "U": 5.2434, "V": 1.623, "W": 1.8102, "X": 0.062422, "Y": 3.0587,
        "Z": 0.31211
    ]

    public static func sample(using rng: inout some RandomNumberGenerator) -> Character {
        weightedSample(from: weights, using: &rng)
    }
}
