import Foundation

/// Prefix trie over uppercase A-Z words, used to prune searches that need to
/// know "is there any valid word starting with this partial string" without
/// re-deriving substrings on every check.
final class TrieNode {
    var children: [Character: TrieNode] = [:]
    var isWord = false
}

final class Trie: @unchecked Sendable {
    private let root = TrieNode()

    init(words: some Sequence<String>) {
        for word in words {
            insert(word)
        }
    }

    private func insert(_ word: String) {
        var node = root
        for ch in word {
            if let existing = node.children[ch] {
                node = existing
            } else {
                let newNode = TrieNode()
                node.children[ch] = newNode
                node = newNode
            }
        }
        node.isWord = true
    }

    func contains(_ word: String) -> Bool {
        node(for: word)?.isWord ?? false
    }

    func hasPrefix(_ prefix: String) -> Bool {
        node(for: prefix) != nil
    }

    private func node(for string: String) -> TrieNode? {
        var node = root
        for ch in string {
            guard let next = node.children[ch] else { return nil }
            node = next
        }
        return node
    }
}
