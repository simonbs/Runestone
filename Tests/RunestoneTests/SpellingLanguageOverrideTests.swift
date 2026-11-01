@testable import Runestone
import UIKit
import XCTest

final class SpellingLanguageOverrideTests: XCTestCase {
    func testBareOverrideOffersAndAppliesCorrectionUsingAnAdvertisedDictionary() throws {
        try XCTSkipUnless(UITextChecker.availableLanguages.contains("en_US"), "English dictionary is unavailable")
        let view = TextView()
        view.autocorrectionType = .no
        view.spellCheckingType = .yes
        view.spellCheckingLanguage = "EN"
        view.text = "👋 A mispelled word."
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        input.isEditing = true
        let range = input.string.range(of: "mispelled")
        input.selectedRange = range
        let suggestion = try XCTUnwrap(input.spellingSuggestions(in: range).first { $0.replacement == "misspelled" })

        XCTAssertEqual(suggestion.languages.count, 1)
        XCTAssertTrue(suggestion.languages.allSatisfy(UITextChecker.availableLanguages.contains))
        input.replaceSpellingSuggestion(suggestion)

        XCTAssertEqual(view.text, "👋 A misspelled word.")
        XCTAssertEqual(view.spellCheckingLanguage, "EN", "Resolution must not rewrite the application's override")
        view.undoManager?.undo()
        XCTAssertEqual(view.text, "👋 A mispelled word.")
    }
}
