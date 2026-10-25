@testable import Runestone
import XCTest

final class SpellingMenuSettingsTests: XCTestCase {
    func testDictionaryActionsAreIndependentOptInsAndPublicAPIsWorkWhileHidden() throws {
        let word = uniqueSpellingWord()
        try XCTSkipIf(TextView.hasLearnedSpellingWord(word), "Preserve an existing learned word")
        defer { TextView.unlearnSpellingWord(word) }
        let (view, input) = try makeEditor(word: word)
        let range = input.string.range(of: word)
        input.selectedRange = range
        XCTAssertTrue(input.spellingWordActions(in: range).isEmpty)
        view.ignoreSpellingWord(word)
        XCTAssertTrue(view.ignoredSpellingWords.contains(word))
        view.resetIgnoredSpellingWords()
        XCTAssertTrue(view.ignoredSpellingWords.isEmpty)
        TextView.learnSpellingWord(word)
        XCTAssertTrue(TextView.hasLearnedSpellingWord(word))
        XCTAssertTrue(input.spellingWordActions(in: range).isEmpty)
        TextView.unlearnSpellingWord(word)
        XCTAssertFalse(TextView.hasLearnedSpellingWord(word))

        view.showIgnoreSpellingAction = true
        XCTAssertEqual(input.spellingWordActions(in: range).map(\.kind), [.ignore])
        view.showIgnoreSpellingAction = false
        view.showLearnSpellingAction = true
        XCTAssertEqual(input.spellingWordActions(in: range).map(\.kind), [.learn])
        TextView.learnSpellingWord(word)
        XCTAssertTrue(input.spellingWordActions(in: range).isEmpty)
        view.showLearnSpellingAction = false
        view.showUnlearnSpellingAction = true
        let actions = input.spellingWordActions(in: range)
        XCTAssertEqual(actions.map(\.kind), [.unlearn])
        input.performSpellingWordAction(try XCTUnwrap(actions.first))
        XCTAssertFalse(TextView.hasLearnedSpellingWord(word))
    }

    func testSingleTapSelectsMisspellingOnlyInsideRenderedWord() throws {
        let (view, input) = try makeEditor(word: "mispelled")
        let window = showEditor(view, input: input)
        defer { window.isHidden = true }
        let range = input.string.range(of: "mispelled")
        let caret = NSRange(location: NSMaxRange(range), length: 0)
        input.selectedRange = caret
        let rect = input.firstRect(for: IndexedRange(range))
        XCTAssertFalse(rect.isEmpty)
        let pointsOutsideWord = [CGPoint(x: 0, y: rect.midY), CGPoint(x: input.bounds.maxX - 1, y: rect.midY)]
        for point in pointsOutsideWord {
            input.presentSpellingMenu(at: point)
            XCTAssertEqual(input.selectedRange, caret, "Gutter and trailing whitespace must retain the caret")
        }

        input.presentSpellingMenu(at: CGPoint(x: rect.midX, y: rect.midY))

        XCTAssertEqual(input.selectedRange, range)
        XCTAssertEqual(view.text, "mispelled")
        input.dismissSpellingMenu()
    }

    func testSingleTapDoesNotSelectWordsWhileSpellingInteractionIsUnavailable() throws {
        let mutations: [(TextView, TextInputView) -> Void] = [
            { view, _ in view.spellCheckingType = .no },
            { view, _ in view.isEditable = false },
            { _, input in input.setWritingToolsActive(true) },
            { _, input in input.setMarkedText("mispelled", selectedRange: NSRange(location: 9, length: 0)) }
        ]
        for mutate in mutations {
            let (view, input) = try makeEditor(word: "mispelled")
            let window = showEditor(view, input: input)
            defer { window.isHidden = true }
            let range = input.string.range(of: "mispelled")
            let rect = input.firstRect(for: IndexedRange(range))
            XCTAssertFalse(rect.isEmpty)
            input.selectedRange = NSRange(location: 0, length: 0)
            mutate(view, input)
            let selection = input.selectedRange

            input.presentSpellingMenu(at: CGPoint(x: rect.midX, y: rect.midY))

            XCTAssertEqual(input.selectedRange, selection)
        }
    }

    private func makeEditor(word: String) throws -> (TextView, TextInputView) {
        try XCTSkipUnless(UITextChecker.availableLanguages.contains("en_US"), "English dictionary is unavailable")
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        view.autocorrectionType = .no
        view.spellCheckingType = .yes
        view.spellCheckingLanguage = "en_US"
        view.text = word
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        input.isEditing = true
        return (view, input)
    }

    private func showEditor(_ view: TextView, input: TextInputView) -> UIWindow {
        view.contentInsetAdjustmentBehavior = .never
        view.showLineNumbers = true
        view.textContainerInset = UIEdgeInsets(top: 11, left: 13, bottom: 7, right: 17)
        let window = UIWindow(frame: view.frame)
        let controller = UIViewController()
        window.rootViewController = controller
        controller.view.addSubview(view)
        window.isHidden = false
        view.layoutIfNeeded()
        input.layoutLines(toLocation: input.string.length)
        input.setNeedsLayout()
        input.layoutIfNeeded()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        return window
    }

    private func uniqueSpellingWord() -> String {
        let letters = Array("abcdefghijklmnop")
        return "zqxvrnstn" + UUID().uuidString.compactMap { $0.hexDigitValue }.prefix(6).map { String(letters[$0]) }.joined()
    }
}
