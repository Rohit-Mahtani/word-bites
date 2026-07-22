import Foundation

/// Picks a key from `weights` with probability proportional to its weight.
/// All weights must be > 0 and at least one entry must be present.
func weightedSample<Key>(from weights: [Key: Double], using rng: inout some RandomNumberGenerator) -> Key {
    let total = weights.values.reduce(0, +)
    precondition(total > 0, "weightedSample requires at least one positive weight")
    var threshold = Double.random(in: 0..<total, using: &rng)
    for (key, weight) in weights {
        if threshold < weight { return key }
        threshold -= weight
    }
    return weights.keys.first!
}
