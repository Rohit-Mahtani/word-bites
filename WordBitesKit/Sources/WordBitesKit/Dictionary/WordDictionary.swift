import Foundation

public enum DictionaryError: Error {
    case resourceNotFound
}

/// Valid-word source for the game. Backed by the ENABLE word list.
/// Words shorter than 3 letters are dropped at load time: the spec treats
/// 2-letter words as invalid/unscored for v1.
public final class WordDictionary: @unchecked Sendable {
    public static let minimumWordLength = 3

    public let words: Set<String>
    private let trie: Trie

    public init(words: some Sequence<String>) {
        let filtered = words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { $0.count >= Self.minimumWordLength && $0.allSatisfy(\.isLetter) }
        self.words = Set(filtered)
        self.trie = Trie(words: self.words)
    }

    public func isValidWord(_ word: String) -> Bool {
        words.contains(word.uppercased())
    }

    /// Whether any word in the dictionary starts with `prefix`. Used to prune
    /// searches that build words up one letter/tile at a time.
    public func hasPrefix(_ prefix: String) -> Bool {
        trie.hasPrefix(prefix.uppercased())
    }
}

public extension WordDictionary {
    static func loadEnable1() throws -> WordDictionary {
        guard let url = Bundle.module.url(forResource: "enable1", withExtension: "txt") else {
            throw DictionaryError.resourceNotFound
        }
        return try load(from: url)
    }

    /// Loads a dictionary from an arbitrary word list file on disk (one word
    /// per line) rather than a bundled resource. For loading a personally
    /// licensed word list that isn't part of the package/repo — never point
    /// this at a file that gets committed or published.
    static func load(from fileURL: URL) throws -> WordDictionary {
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = contents.split(whereSeparator: \.isNewline).map(String.init)
        return WordDictionary(words: lines)
    }
}
