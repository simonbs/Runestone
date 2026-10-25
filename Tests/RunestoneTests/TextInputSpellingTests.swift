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
        input.writingToolsExcludedRangesProvider = { _ in [range] }
        XCTAssertNil(input.replaceTextForWritingTools(in: range, with: "misspelled"))
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

    func testCorrectionRejectsDirectlyLearnedWordBeforeAndDuringEditApproval() throws {
        try XCTSkipIf(UITextChecker.hasLearnedWord("mispelled"), "Preserve an existing learned word")
        for learnDuringApproval in [false, true] {
            defer { TextView.unlearnSpellingWord("mispelled") }
            let (view, input) = try makeEditor()
            let delegate = SpellingDelegate()
            view.editorDelegate = delegate
            let range = input.string.range(of: "mispelled")
            input.selectedRange = range
            let suggestion = try correction(in: input, range: range)
            var didRequestEdit = false
            delegate.onEdit = {
                didRequestEdit = true
                if learnDuringApproval {
                    UITextChecker.learnWord("mispelled")
                }
            }
            if !learnDuringApproval {
                UITextChecker.learnWord("mispelled")
            }

            input.replaceSpellingSuggestion(suggestion)

            XCTAssertTrue(UITextChecker.hasLearnedWord("mispelled"))
            XCTAssertEqual(didRequestEdit, learnDuringApproval)
            XCTAssertEqual(view.text, "👋 A mispelled word.")
            XCTAssertEqual(view.selectedRange, range)
            XCTAssertFalse(view.undoManager?.canUndo ?? true)
        }
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

}

extension TextInputSpellingTests {
    func testIgnoringWordIsDocumentScopedAndDoesNotChangeTextOrUndoHistory() throws {
        let (view, input) = try makeEditor()
        let (otherView, otherInput) = try makeEditor()
        input.selectedRange = NSRange(location: input.string.length, length: 0)
        input.insertText("!")
        let range = input.string.range(of: "mispelled")
        input.selectedRange = range
        otherInput.selectedRange = range
        let action = try XCTUnwrap(input.spellingWordActions(in: range).first { $0.kind == .ignore })

        input.performSpellingWordAction(action)

        XCTAssertTrue(view.ignoredSpellingWords.contains("mispelled"))
        XCTAssertTrue(input.spellingSuggestions(in: range).isEmpty)
        XCTAssertEqual(view.text, "👋 A mispelled word.!")
        XCTAssertEqual(view.selectedRange, range)
        XCTAssertTrue(otherView.ignoredSpellingWords.isEmpty)
        XCTAssertFalse(otherInput.spellingSuggestions(in: range).isEmpty)
        view.undoManager?.undo()
        XCTAssertEqual(view.text, "👋 A mispelled word.", "Ignoring must not consume an undo step")
        XCTAssertTrue(view.ignoredSpellingWords.contains("mispelled"))

        view.spellCheckingType = .no
        view.spellCheckingType = .yes
        view.spellCheckingLanguage = "unsupported-language"
        view.spellCheckingLanguage = "en_US"
        input.selectedRange = range
        XCTAssertTrue(input.spellingSuggestions(in: range).isEmpty)
        view.resetIgnoredSpellingWords()
        XCTAssertFalse(input.spellingSuggestions(in: range).isEmpty)
    }

    func testReplacingDocumentResetsIgnoredWordsEvenWhenTextIsUnchanged() throws {
        let (view, input) = try makeEditor()
        let text = view.text
        view.ignoreSpellingWord("mispelled")
        view.text = text
        XCTAssertTrue(view.ignoredSpellingWords.isEmpty)
        let range = input.string.range(of: "mispelled")
        input.selectedRange = range
        XCTAssertFalse(input.spellingSuggestions(in: range).isEmpty)

        view.ignoreSpellingWord("mispelled")
        view.setState(TextViewState(text: text))
        XCTAssertTrue(view.ignoredSpellingWords.isEmpty)
        input.selectedRange = range
        XCTAssertFalse(input.spellingSuggestions(in: range).isEmpty)
    }

    func testLearningAndUnlearningRefreshOtherEditorsWithoutChangingText() throws {
        let word = uniqueSpellingWord()
        try XCTSkipIf(TextView.hasLearnedSpellingWord(word), "Preserve an existing learned word")
        defer { TextView.unlearnSpellingWord(word) }
        let (view, input) = try makeEditor(word: word)
        let (otherView, otherInput) = try makeEditor(word: word)
        let range = input.string.range(of: word)
        input.selectedRange = range
        otherInput.selectedRange = range
        let learn = try XCTUnwrap(input.spellingWordActions(in: range).first { $0.kind == .learn })
        let staleIgnore = try XCTUnwrap(otherInput.spellingWordActions(in: range).first { $0.kind == .ignore })

        view.showLearnSpellingAction = false
        input.performSpellingWordAction(learn)
        XCTAssertFalse(TextView.hasLearnedSpellingWord(word))
        view.showLearnSpellingAction = true
        input.performSpellingWordAction(learn)
        XCTAssertFalse(TextView.hasLearnedSpellingWord(word), "Reenabling must not revive an old menu")
        input.performSpellingWordAction(try XCTUnwrap(input.spellingWordActions(in: range).first { $0.kind == .learn }))

        XCTAssertTrue(TextView.hasLearnedSpellingWord(word))
        XCTAssertTrue(input.spellingSuggestions(in: range).isEmpty)
        otherInput.performSpellingWordAction(staleIgnore)
        XCTAssertTrue(otherView.ignoredSpellingWords.isEmpty, "Learning elsewhere must invalidate an open menu")
        let unlearn = try XCTUnwrap(otherInput.spellingWordActions(in: range).first { $0.kind == .unlearn })
        otherView.showUnlearnSpellingAction = false
        otherInput.performSpellingWordAction(unlearn)
        XCTAssertTrue(TextView.hasLearnedSpellingWord(word))
        otherView.showUnlearnSpellingAction = true
        otherInput.performSpellingWordAction(unlearn)
        XCTAssertTrue(TextView.hasLearnedSpellingWord(word), "Reenabling must not revive an old menu")
        otherInput.performSpellingWordAction(try XCTUnwrap(otherInput.spellingWordActions(in: range).first { $0.kind == .unlearn }))
        XCTAssertFalse(TextView.hasLearnedSpellingWord(word))
        XCTAssertTrue(input.spellingWordActions(in: range).contains { $0.kind == .learn })
        XCTAssertEqual(view.text, "👋 A \(word) word.")
        XCTAssertEqual(otherView.text, view.text)
        XCTAssertEqual(view.selectedRange, range)
        XCTAssertEqual(otherView.selectedRange, range)
        XCTAssertFalse(view.undoManager?.canUndo ?? true)
        XCTAssertFalse(otherView.undoManager?.canUndo ?? true)
    }

    func testRelearningThroughPublicAPIsInvalidatesAnOpenUnlearnAction() throws {
        let word = uniqueSpellingWord()
        try XCTSkipIf(TextView.hasLearnedSpellingWord(word), "Preserve an existing learned word")
        defer { TextView.unlearnSpellingWord(word) }
        let (_, input) = try makeEditor(word: word)
        let range = input.string.range(of: word)
        input.selectedRange = range
        TextView.learnSpellingWord(word)
        let action = try XCTUnwrap(input.spellingWordActions(in: range).first { $0.kind == .unlearn })

        TextView.unlearnSpellingWord(word)
        TextView.learnSpellingWord(word)
        input.performSpellingWordAction(action)

        XCTAssertTrue(TextView.hasLearnedSpellingWord(word), "A stale menu must not unlearn a newly learned word")
    }

    func testDictionaryActionsRejectChangedSelectionDocumentAndLanguage() throws {
        let mutations: [(TextView, TextInputView) -> Void] = [
            { _, input in input.selectedRange = NSRange(location: 0, length: 0) },
            { view, _ in view.text = "👋 A mispelled sentence." },
            { view, _ in view.spellCheckingLanguage = "unsupported-language" },
            { view, _ in view.spellCheckingType = .no },
            { view, _ in
                view.showIgnoreSpellingAction = false
                view.showIgnoreSpellingAction = true
            },
            { _, input in input.isEditing = false },
            { view, _ in view.isEditable = false },
            { _, input in input.setWritingToolsActive(true) },
            { _, input in input.setMarkedText("mispelled", selectedRange: NSRange(location: 9, length: 0)) }
        ]
        for (index, mutate) in mutations.enumerated() {
            let (view, input) = try makeEditor()
            let range = input.string.range(of: "mispelled")
            input.selectedRange = range
            let action = try XCTUnwrap(input.spellingWordActions(in: range).first { $0.kind == .ignore })
            mutate(view, input)

            input.performSpellingWordAction(action)

            XCTAssertTrue(view.ignoredSpellingWords.isEmpty, "Stale action case \(index)")
        }
    }

    func testDictionaryActionsRespectRangePolicyAndRecheckAfterDelegateCallback() throws {
        let (view, input) = try makeEditor()
        let delegate = SpellingDelegate()
        view.editorDelegate = delegate
        let range = input.string.range(of: "mispelled")
        input.selectedRange = range
        delegate.checkSpelling = false
        XCTAssertTrue(input.spellingWordActions(in: range).isEmpty)
        delegate.checkSpelling = true
        let action = try XCTUnwrap(input.spellingWordActions(in: range).first { $0.kind == .ignore })
        delegate.checkSpelling = false
        input.performSpellingWordAction(action)
        XCTAssertTrue(view.ignoredSpellingWords.isEmpty)

        delegate.checkSpelling = true
        delegate.onCheckSpelling = { input.selectedRange = NSRange(location: 0, length: 0) }
        input.performSpellingWordAction(action)
        XCTAssertTrue(view.ignoredSpellingWords.isEmpty)
        input.selectedRange = range
        XCTAssertTrue(input.spellingWordActions(in: range).isEmpty, "A reentrant selection change must not create a menu")

        delegate.onCheckSpelling = nil
        input.selectedRange = range
        let nextAction = try XCTUnwrap(input.spellingWordActions(in: range).first { $0.kind == .ignore })
        delegate.onCheckSpelling = { view.text = "New document" }
        input.performSpellingWordAction(nextAction)
        XCTAssertEqual(view.text, "New document")
        XCTAssertTrue(view.ignoredSpellingWords.isEmpty)
    }

    private func uniqueSpellingWord() -> String {
        let letters = Array("abcdefghijklmnop")
        return "zqxvrnstn" + UUID().uuidString.compactMap { $0.hexDigitValue }.prefix(6).map { String(letters[$0]) }.joined()
    }

    private func makeEditor(word: String = "mispelled") throws -> (TextView, TextInputView) {
        try XCTSkipUnless(UITextChecker.availableLanguages.contains("en_US"), "English dictionary is unavailable")
        let view = TextView()
        view.showIgnoreSpellingAction = true
        view.showLearnSpellingAction = true
        view.showUnlearnSpellingAction = true
        view.autocorrectionType = .no
        view.spellCheckingType = .yes
        view.spellCheckingLanguage = "en_US"
        view.text = "👋 A \(word) word."
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
    var onCheckSpelling: (() -> Void)?

    func textView(_ textView: TextView, shouldCheckSpellingIn range: NSRange) -> Bool {
        onCheckSpelling?()
        return checkSpelling
    }

    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        onEdit?()
        return allowEdits
    }
}
