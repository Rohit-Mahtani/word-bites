import XCTest
@testable import WordBitesKit

final class WordDictionaryTests: XCTestCase {
    func testFiltersOutShortAndNonAlphaEntries() {
        let dict = WordDictionary(words: ["cat", "ok", "a1b", "dog", "z"])
        XCTAssertTrue(dict.isValidWord("cat"))
        XCTAssertTrue(dict.isValidWord("dog"))
        XCTAssertFalse(dict.isValidWord("ok"))
        XCTAssertFalse(dict.isValidWord("a1b"))
        XCTAssertFalse(dict.isValidWord("z"))
    }

    func testIsValidWordIsCaseInsensitive() {
        let dict = WordDictionary(words: ["cat"])
        XCTAssertTrue(dict.isValidWord("CAT"))
        XCTAssertTrue(dict.isValidWord("Cat"))
    }

    func testHasPrefix() {
        let dict = WordDictionary(words: ["cat", "car", "dog"])
        XCTAssertTrue(dict.hasPrefix("ca"))
        XCTAssertTrue(dict.hasPrefix("c"))
        XCTAssertFalse(dict.hasPrefix("cx"))
    }

    func testLoadDefaultFromBundleResource() throws {
        let dict = try WordDictionary.loadDefault()
        XCTAssertTrue(dict.isValidWord("word"))
        XCTAssertTrue(dict.isValidWord("bites"))
        XCTAssertFalse(dict.isValidWord("zzzzqqqq"))
        // Spec: 2-letter words are treated as invalid for v1.
        XCTAssertFalse(dict.isValidWord("aa"))
        XCTAssertGreaterThan(dict.words.count, 100_000)
    }
}
