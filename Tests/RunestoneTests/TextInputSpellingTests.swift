@testable import Runestone
import XCTest

final class TextInputSpellingTests: XCTestCase {
    func testCorrectionPreservesUnicodeAndIsAnIndependentUndoStep() throws {
        let (view, input) = try makeEditor()
        input.selectedRange = NSRange(location: input.string.length, length: 0)
        input.insertText("!")
        let wordRange = input.string.range(of: "mispelled")
        input.selectedRange = wordRange
        let suggestion = try correction(in: input, range: wordRange)

        input.replaceSpellingSuggestion(suggestion)

        XCTAssertEqual(view.text, "👋 A misspelled word.!")
        XCTAssertEqual(view.selectedRange, NSRange(location: wordRange.location + "misspelled".utf16.count, length: 0))
        view.undoManager?.undo()
        XCTAssertEqual(view.text, "👋 A mispelled word.!")
        XCTAssertEqual(view.selectedRange, wordRange)
        view.undoManager?.redo()
        XCTAssertEqual(view.text, "👋 A misspelled word.!")
        view.undoManager?.undo()
        view.undoManager?.undo()
        XCTAssertEqual(view.text, "👋 A mispelled word.")
    }

    func testSuggestionCannotReplaceTextAfterDocumentOrSelectionChanges() throws {
        let (_, input) = try makeEditor()
        let range = input.string.range(of: "mispelled")
        input.selectedRange = range
        let suggestion = try correction(in: input, range: range)
        input.selectedRange = NSRange(location: 0, length: 0)
        input.replaceSpellingSuggestion(suggestion)
        XCTAssertEqual(input.string, "👋 A mispelled word.")

        input.selectedRange = range
        input.string = "👋 A mispelled sentence."
        input.replaceSpellingSuggestion(suggestion)
        XCTAssertEqual(input.string, "👋 A mispelled sentence.")
    }

    func testWritingToolsSuppressesSpellingAndRejectsAnAlreadyPresentedCorrection() throws {
        let (view, input) = try makeEditor()
        let originalText = view.text
        let range = input.string.range(of: "mispelled")
        input.selectedRange = range
        let suggestion = try correction(in: input, range: range)

        input.setWritingToolsActive(true)

        XCTAssertTrue(input.spellingSuggestions(in: range).isEmpty)
        input.replaceSpellingSuggestion(suggestion)
        XCTAssertEqual(view.text, originalText)
        XCTAssertEqual(view.selectedRange, range)
        XCTAssertFalse(view.undoManager?.canUndo ?? true)

        let revisedText = "👋 A mispelled sentence."
        XCTAssertEqual(input.replaceTextForWritingTools(in: NSRange(location: 0, length: input.string.length),
                                                        with: revisedText), revisedText)
        input.selectedRange = range
        XCTAssertTrue(input.spellingSuggestions(in: range).isEmpty)
        input.replaceSpellingSuggestion(suggestion)
        XCTAssertEqual(view.text, revisedText)

        input.setWritingToolsActive(false)
        input.replaceSpellingSuggestion(suggestion)
        XCTAssertEqual(view.text, revisedText, "Ending a session must not revive an old menu action")
        XCTAssertFalse(input.spellingSuggestions(in: range).isEmpty)
    }

    func testSpellingCorrectionAfterWritingToolsHasItsOwnUndoStep() throws {
        let (view, input) = try makeEditor()
        let originalText = view.text
        let originalSelection = input.string.range(of: "mispelled")
        input.selectedRange = originalSelection
        input.setWritingToolsActive(true)
        let provisionalText = "A preliminary mispelled revision."
        XCTAssertEqual(input.replaceTextForWritingTools(in: NSRange(location: 0, length: input.string.length),
                                                        with: provisionalText), provisionalText)
        let revisedText = "👋 Here is the final mispelled sentence."
        XCTAssertEqual(input.replaceTextForWritingTools(in: NSRange(location: 0, length: input.string.length),
                                                        with: revisedText), revisedText)
        input.setWritingToolsActive(false)
        let range = input.string.range(of: "mispelled")
        input.selectedRange = range
        let suggestion = try correction(in: input, range: range)

        input.replaceSpellingSuggestion(suggestion)

        XCTAssertEqual(view.text, "👋 Here is the final misspelled sentence.")
        let undoManager = try XCTUnwrap(view.undoManager)
        undoManager.undo()
        XCTAssertEqual(view.text, revisedText, "Undoing spelling must preserve the final Writing Tools revision")
        XCTAssertEqual(view.selectedRange, range)
        undoManager.undo()
        XCTAssertEqual(view.text, originalText, "The Writing Tools session remains a separate undo step")
        XCTAssertEqual(view.selectedRange, originalSelection)
        undoManager.redo()
        XCTAssertEqual(view.text, revisedText)
        undoManager.redo()
        XCTAssertEqual(view.text, "👋 Here is the final misspelled sentence.")
    }

    func testSpellingPolicyAndEditVetoAreRespected() throws {
        let (view, input) = try makeEditor()
        let delegate = SpellingDelegate()
        view.editorDelegate = delegate
        let range = input.string.range(of: "mispelled")
        input.selectedRange = range
        delegate.checkSpelling = false
        XCTAssertTrue(input.spellingSuggestions(in: range).isEmpty)

        delegate.checkSpelling = true
        view.invalidateSpellChecking()
        let suggestion = try correction(in: input, range: range)
        delegate.allowEdits = false
        input.replaceSpellingSuggestion(suggestion)
        XCTAssertEqual(view.text, "👋 A mispelled word.")
        XCTAssertFalse(view.undoManager?.canUndo ?? true)
    }

    func testDelegateChangingDocumentDuringCorrectionCannotApplyStaleRange() throws {
        let (view, input) = try makeEditor()
        let delegate = SpellingDelegate()
        view.editorDelegate = delegate
        let range = input.string.range(of: "mispelled")
        input.selectedRange = range
        let suggestion = try correction(in: input, range: range)
        delegate.onEdit = { view.text = "New document" }

        input.replaceSpellingSuggestion(suggestion)

        XCTAssertEqual(view.text, "New document")
    }

    func testDisabledUnsupportedLanguageAndCompositionDoNotOfferCorrections() throws {
        let (view, input) = try makeEditor()
        let range = input.string.range(of: "mispelled")
        input.selectedRange = range
        XCTAssertFalse(input.spellingSuggestions(in: range).isEmpty)
        XCTAssertTrue(input.spellingSuggestions(in: NSRange(location: NSNotFound, length: 0)).isEmpty)
        XCTAssertTrue(input.spellingSuggestions(in: NSRange(location: 1, length: 0)).isEmpty, "Do not split the opening emoji")
        view.spellCheckingType = .no
        XCTAssertTrue(input.spellingSuggestions(in: range).isEmpty)
        view.spellCheckingType = .default
        XCTAssertTrue(input.spellingSuggestions(in: range).isEmpty, "Default follows disabled autocorrection")
        view.spellCheckingType = .yes
        view.spellCheckingLanguage = "unsupported-language"
        XCTAssertTrue(input.spellingSuggestions(in: range).isEmpty)
        view.spellCheckingLanguage = "en_US"
        input.setMarkedText("mispelled", selectedRange: NSRange(location: 9, length: 0))
        XCTAssertTrue(input.spellingSuggestions(in: range).isEmpty)
        input.unmarkText()
        input.selectedRange = range
        XCTAssertFalse(input.spellingSuggestions(in: range).isEmpty)
    }

    private func makeEditor() throws -> (TextView, TextInputView) {
        try XCTSkipUnless(UITextChecker.availableLanguages.contains("en_US"), "English dictionary is unavailable")
        let view = TextView()
        view.autocorrectionType = .no
        view.spellCheckingType = .yes
        view.spellCheckingLanguage = "en_US"
        view.text = "👋 A mispelled word."
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        input.isEditing = true
        return (view, input)
    }

    private func correction(in input: TextInputView, range: NSRange) throws -> SpellingSuggestion {
        try XCTUnwrap(input.spellingSuggestions(in: range).first { $0.replacement == "misspelled" })
    }
}

private final class SpellingDelegate: TextViewDelegate {
    var checkSpelling = true
    var allowEdits = true
    var onEdit: (() -> Void)?

    func textView(_ textView: TextView, shouldCheckSpellingIn range: NSRange) -> Bool {
        checkSpelling
    }

    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        onEdit?()
        return allowEdits
    }
}
