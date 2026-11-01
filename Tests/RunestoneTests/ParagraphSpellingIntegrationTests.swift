import Foundation
@testable import Runestone
import UIKit
import XCTest

final class ParagraphSpellingIntegrationTests: XCTestCase {
    private let english = "This paragraph explains why the editor reports hus as an English spelling mistake for its readers."
    private let danish = "Dette afsnit forklarer hvorfor editoren viser house som en stavefejl for alle sine danske læsere."

    func testNarrowedParagraphDictionariesFlagCrossLanguageFalseNegativesWithMenuParity() {
        let fixture = DetectionFixture { text in text.contains("Dette") ? ["da": 0.99] : ["en": 0.99] }
        let text = (english + "\n\n" + danish + "\n\nhus house typo") as NSString
        let fallback = ["en_US", "da_DK"]
        fixture.update(text as String, available: fallback)
        fixture.scheduler.complete()
        let service = SpellCheckingService(checker: ParagraphDictionaryChecker(), debounceInterval: 0)
        let englishMistake = text.range(of: "hus")
        let danishMistake = text.range(of: "house")
        let trueTypo = text.range(of: "typo")
        let completed = expectation(description: "Paragraph dictionaries checked")
        service.schedule(text: text, visibleRanges: [NSRange(location: 0, length: text.length)], languages: fallback,
                         languageRegions: fixture.service.regions) { ranges in
            XCTAssertEqual(ranges, [englishMistake, danishMistake, trueTypo])
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)

        let englishLanguages = fixture.service.languages(for: englishMistake, fallback: fallback)
        let danishLanguages = fixture.service.languages(for: danishMistake, fallback: fallback)
        XCTAssertTrue(service.isMisspelled(for: englishMistake, in: text, languages: englishLanguages))
        XCTAssertEqual(service.suggestions(for: englishMistake, in: text, languages: englishLanguages), ["en_US-correction"])
        XCTAssertTrue(service.isMisspelled(for: danishMistake, in: text, languages: danishLanguages))
        XCTAssertEqual(service.suggestions(for: danishMistake, in: text, languages: danishLanguages), ["da_DK-correction"])
        let fallbackWord = text.range(of: "hus", options: .backwards)
        XCTAssertFalse(service.isMisspelled(for: fallbackWord, in: text, languages: fixture.service.languages(for: fallbackWord, fallback: fallback)))
    }

    func testExplicitOverrideBypassesDetectionButAutomaticLayoutRequestsIt() throws {
        let editor = try makeEditor()
        let view = editor.view
        let input = editor.input
        let fixture = editor.detection
        view.spellCheckingLanguage = "EN"
        view.layoutIfNeeded()
        input.layoutSubviews()
        fixture.scheduler.complete()
        XCTAssertTrue(fixture.detector.texts.isEmpty)

        view.spellCheckingLanguage = nil
        view.setNeedsLayout()
        view.layoutIfNeeded()
        input.layoutSubviews()
        fixture.scheduler.complete()
        XCTAssertFalse(fixture.detector.texts.isEmpty, "The same visible prose must request detection when automatic mode is enabled.")
    }

    func testSelectedWordMenuUsesDetectedDictionaryAndAnExplicitOverrideReplacesIt() throws {
        let editor = try makeEditor()
        let view = editor.view
        let input = editor.input
        let fixture = editor.detection
        fixture.update(view.text, available: ["en_US"])
        fixture.scheduler.complete()
        let range = input.string.range(of: "zqxvparagraph")
        input.selectedRange = range
        let action = try XCTUnwrap(input.spellingWordActions(in: range).first { $0.kind == .ignore })
        XCTAssertEqual(action.target.languages, ["en_US"])

        view.spellCheckingLanguage = "zz_ZZ"
        XCTAssertTrue(input.spellingWordActions(in: range).isEmpty)
        input.performSpellingWordAction(action)
        XCTAssertTrue(view.ignoredSpellingWords.isEmpty, "An override must invalidate an already presented automatic-language action.")
    }

    func testImmediateMenuKeepsDetectedDictionaryAcrossSelectionAndNontextInvalidation() throws {
        try XCTSkipUnless(UITextChecker.availableLanguages.contains("fr_FR"), "French dictionary is unavailable")
        let editor = try makeEditor()
        let fixture = DetectionFixture { _ in ["fr": 0.99] }
        editor.input.paragraphSpellingLanguageService = fixture.service
        fixture.update(editor.view.text, available: ["fr_FR"])
        fixture.scheduler.complete()
        let word = editor.input.string.range(of: "zqxvparagraph")

        editor.input.selectedRange = NSRange(location: 0, length: 0)
        editor.input.selectedRange = word
        editor.view.invalidateSpellChecking()
        let action = try XCTUnwrap(editor.input.spellingWordActions(in: word).first { $0.kind == .ignore })
        XCTAssertEqual(action.target.languages, ["fr_FR"], "Immediate menus must retain the paragraph dictionary without waiting for layout.")
    }

    func testImmediateMenuAfterTextInsertionDoesNotReuseAnotherParagraphsCoordinates() throws {
        try XCTSkipUnless(UITextChecker.availableLanguages.contains("fr_FR"), "French dictionary is unavailable")
        let editor = try makeEditor()
        let fixture = DetectionFixture { _ in ["fr": 0.99] }
        editor.input.paragraphSpellingLanguageService = fixture.service
        fixture.update(editor.view.text, available: ["fr_FR"])
        fixture.scheduler.complete()
        let fallback = SpellingLanguageResolver.resolve(
            explicitLanguage: nil,
            keyboardLanguages: [editor.input.textInputMode?.primaryLanguage].compactMap { $0 }
                + UITextInputMode.activeInputModes.compactMap { $0.primaryLanguage },
            preferredLanguages: Locale.preferredLanguages, availableLanguages: UITextChecker.availableLanguages
        )

        editor.input.selectedRange = NSRange(location: 0, length: 0)
        let newParagraph = "A newly inserted explanation includes zqxvparagraph and unrelated information about important document features.\n\n"
        editor.input.insertText(newParagraph)
        let word = editor.input.string.range(of: "zqxvparagraph")
        editor.input.selectedRange = word
        let action = try XCTUnwrap(editor.input.spellingWordActions(in: word).first { $0.kind == .ignore })
        XCTAssertEqual(action.target.languages, fallback,
                       "New prose at an old coordinate must not inherit the previous paragraph's detected language.")
    }

    func testDocumentResetDisableAndOverrideDiscardInFlightAutomaticDetection() throws {
        let mutations: [(TextView) -> Void] = [
            { $0.text = "A completely different document replaces the text that was captured for pending detection." },
            { $0.spellCheckingType = .no },
            { $0.spellCheckingLanguage = "en_US" }
        ]
        for mutate in mutations {
            let editor = try makeEditor()
            let view = editor.view
            let fixture = editor.detection
            fixture.update(view.text, available: ["en_US"])
            fixture.scheduler.runDebounced()
            XCTAssertEqual(fixture.scheduler.inferences.count, 1)
            mutate(view)
            fixture.scheduler.complete()
            XCTAssertTrue(fixture.service.regions.isEmpty, "A completed worker must not restore a superseded automatic-language policy.")
        }
    }

    private func makeEditor() throws -> ParagraphEditorFixture {
        try XCTSkipUnless(UITextChecker.availableLanguages.contains("en_US"), "English dictionary is unavailable")
        try XCTSkipIf(UITextChecker.hasLearnedWord("zqxvparagraph"), "Preserve an existing learned word")
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        view.showIgnoreSpellingAction = true
        view.autocorrectionType = .no
        view.spellCheckingType = .yes
        view.text = english + " The word zqxvparagraph is an intentional spelling mistake in this paragraph."
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        input.isEditing = true
        let fixture = DetectionFixture { _ in ["en": 0.99] }
        input.paragraphSpellingLanguageService = fixture.service
        return ParagraphEditorFixture(view: view, input: input, detection: fixture)
    }
}

private struct ParagraphEditorFixture {
    let view: TextView
    let input: TextInputView
    let detection: DetectionFixture
}

private final class ParagraphDictionaryChecker: SpellChecking {
    var ignoredWords: [String]?

    func ignoreWord(_ wordToIgnore: String) {
        ignoredWords = (ignoredWords ?? []) + [wordToIgnore]
    }

    func rangeOfMisspelledWord(in string: String, range: NSRange, startingAt offset: Int, wrap: Bool, language: String) -> NSRange {
        let text = string as NSString
        let searchRange = NSRange(location: offset, length: text.length - offset)
        let candidates = language == "en_US" ? ["hus", "typo"] : ["house", "typo"]
        return candidates.filter { !(ignoredWords ?? []).contains($0) }
            .map { text.range(of: $0, range: searchRange) }
            .filter { $0.location != NSNotFound }
            .min { $0.location < $1.location } ?? NSRange(location: NSNotFound, length: 0)
    }

    func guesses(forWordRange range: NSRange, in string: String, language: String) -> [String]? {
        [language + "-correction"]
    }
}
