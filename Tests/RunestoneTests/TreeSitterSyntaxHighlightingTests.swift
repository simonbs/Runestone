@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

final class TreeSitterSyntaxHighlightingTests: XCTestCase {
    func testHighlightEmbeddedJavaScriptWithUnicodeAndTextPredicates() throws {
        let javaScript = TreeSitterLanguage(
            tree_sitter_javascript(),
            highlightsQuery: .init(string: """
            ((identifier) @keyword (#eq? @keyword "target"))
            (string) @string
            (number) @number
            """))
        let html = TreeSitterLanguage(
            tree_sitter_html(),
            highlightsQuery: .init(string: "(tag_name) @type"),
            injectionsQuery: .init(string: """
            ((script_element (raw_text) @injection.content)
             (#set! injection.language "javascript"))
            """))
        let theme = DefaultTheme()
        let provider = JavaScriptLanguageProvider(language: javaScript)
        let highlighter = StringSyntaxHighlighter(theme: theme, language: html, languageProvider: provider)
        let text = "<p>target 😀</p><script>let target = \"Grøn 😀\"; let ignored = 42;</script>"
        let highlighted = highlighter.syntaxHighlight(text)
        let source = text as NSString

        XCTAssertEqual(highlighted.string, text)
        assertColor(theme.textColor, in: source.range(of: "target 😀"), of: highlighted)
        assertColor(try XCTUnwrap(theme.textColor(for: "type")), in: source.range(of: "script"), of: highlighted)
        let scriptTarget = source.range(of: "target", options: .backwards)
        assertColor(try XCTUnwrap(theme.textColor(for: "keyword")), in: scriptTarget, of: highlighted)
        assertColor(try XCTUnwrap(theme.textColor(for: "string")), in: source.range(of: "\"Grøn 😀\""), of: highlighted)
        assertColor(try XCTUnwrap(theme.textColor(for: "number")), in: source.range(of: "42"), of: highlighted)
        assertColor(theme.textColor, in: source.range(of: "ignored"), of: highlighted)
        assertColor(theme.textColor, in: source.range(of: ";"), of: highlighted)
    }

    @MainActor
    func testInvalidatedInputCannotApplyCompletedBackgroundCaptures() throws {
        let context = makeAsyncContext(text: "let target = 42;")
        let input = makeInput("let target = 42;")
        let original = NSAttributedString(attributedString: input.attributedString)
        let rejected = expectation(description: "Invalidated result rejected")
        context.highlighter.syntaxHighlight(input) { result in
            if case .success = result { XCTFail("An invalidated input must not succeed.") }
            rejected.fulfill()
        }
        // Finish capture collection while the main queue is held by this test.
        // Invalidation therefore happens immediately before the pending apply.
        context.queue.waitUntilAllOperationsAreFinished()
        input.isValid = { false }
        wait(for: [rejected], timeout: 5)
        XCTAssertTrue(input.attributedString.isEqual(to: original))
    }

    @MainActor
    func testCancelledCompletedRequestCannotOverwriteReplacementStyles() throws {
        let context = makeAsyncContext(text: "let target = 42;")
        let input = makeInput("let target = 42;")
        let original = NSAttributedString(attributedString: input.attributedString)
        let rejected = expectation(description: "Canceled completed result rejected")
        context.highlighter.syntaxHighlight(input) { result in
            if case .success = result { XCTFail("A canceled request must not succeed.") }
            XCTAssertTrue(input.attributedString.isEqual(to: original))
            rejected.fulfill()
        }
        context.queue.waitUntilAllOperationsAreFinished()
        context.highlighter.cancel()
        let applied = expectation(description: "Replacement request applied")
        context.highlighter.syntaxHighlight(input) { result in
            if case .failure(let error) = result { XCTFail("Replacement failed: \(error)") }
            applied.fulfill()
        }
        context.queue.waitUntilAllOperationsAreFinished()
        wait(for: [rejected, applied], timeout: 5)
        assertColor(try XCTUnwrap(context.highlighter.theme.textColor(for: "keyword")),
                    in: (input.attributedString.string as NSString).range(of: "target"), of: input.attributedString)
        assertColor(try XCTUnwrap(context.highlighter.theme.textColor(for: "number")),
                    in: (input.attributedString.string as NSString).range(of: "42"), of: input.attributedString)
    }

    @MainActor
    func testThemeCallbackCancellationRejectsStylesBeforeMutation() {
        let context = makeAsyncContext(text: "let target = 42;")
        let input = makeInput("let target = 42;")
        let original = NSAttributedString(attributedString: input.attributedString)
        let theme = CancellingHighlightTheme()
        var didCancel = false
        theme.onHighlight = { [weak highlighter = context.highlighter] in
            didCancel = true
            highlighter?.cancel()
        }
        context.highlighter.theme = theme
        let rejected = expectation(description: "Reentrant cancellation rejected")
        context.highlighter.syntaxHighlight(input) { result in
            if case .success = result { XCTFail("Cancellation during a theme callback must reject the result.") }
            rejected.fulfill()
        }
        context.queue.waitUntilAllOperationsAreFinished()
        wait(for: [rejected], timeout: 5)
        XCTAssertTrue(didCancel, "The request must reach token construction before cancellation.")
        XCTAssertTrue(input.attributedString.isEqual(to: original),
                      "Tokens computed by the canceled request must not mutate the attributed string.")
    }

    @MainActor
    func testQueuedRequestUsesCapturedTreeAndPredicateTextAfterDocumentReplacement() throws {
        let originalText = "let target = 42;"
        let context = makeAsyncContext(text: originalText)
        context.queue.isSuspended = true
        defer { context.queue.isSuspended = false }
        let input = makeInput(originalText)
        let applied = expectation(description: "Snapshot request applied")
        context.highlighter.syntaxHighlight(input) { result in
            if case .failure(let error) = result { XCTFail("Snapshot failed: \(error)") }
            applied.fulfill()
        }
        // This low-level input deliberately remains valid to inspect the captured
        // generation independently of the controller's stale-result rejection.
        context.stringView.string = "let ignored = false;" as NSString
        context.mode.parse(context.stringView.string)
        context.queue.isSuspended = false
        context.queue.waitUntilAllOperationsAreFinished()
        wait(for: [applied], timeout: 5)
        assertColor(try XCTUnwrap(context.highlighter.theme.textColor(for: "keyword")),
                    in: (originalText as NSString).range(of: "target"), of: input.attributedString)
        assertColor(try XCTUnwrap(context.highlighter.theme.textColor(for: "number")),
                    in: (originalText as NSString).range(of: "42"), of: input.attributedString)
    }

    private struct AsyncContext {
        let highlighter: TreeSitterSyntaxHighlighter
        let mode: TreeSitterInternalLanguageMode
        let queue: OperationQueue
        let stringView: StringView
    }

    private func makeAsyncContext(text: String) -> AsyncContext {
        let language = TreeSitterLanguage(tree_sitter_javascript(), highlightsQuery: .init(string: """
        ((identifier) @keyword (#eq? @keyword "target"))
        (number) @number
        """))
        let stringView = StringView(string: text)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let mode = TreeSitterInternalLanguageMode(language: language.internalLanguage, languageProvider: nil,
                                                  stringView: stringView, lineManager: lineManager)
        mode.parse(stringView.string)
        let queue = OperationQueue()
        let highlighter = TreeSitterSyntaxHighlighter(stringView: stringView, languageMode: mode, operationQueue: queue)
        return AsyncContext(highlighter: highlighter, mode: mode, queue: queue, stringView: stringView)
    }

    private func makeInput(_ text: String) -> LineSyntaxHighlighterInput {
        let string = NSMutableAttributedString(string: text, attributes: [
            .foregroundColor: UIColor.black,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ])
        return LineSyntaxHighlighterInput(attributedString: string,
                                          byteRange: ByteRange(utf16Range: NSRange(location: 0, length: string.length)))
    }

    private func assertColor(_ expected: UIColor, in range: NSRange, of string: NSAttributedString,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotEqual(range.location, NSNotFound, file: file, line: line)
        guard range.location != NSNotFound else {
            return
        }
        string.enumerateAttribute(.foregroundColor, in: range) { value, _, _ in
            XCTAssertEqual(value as? UIColor, expected, file: file, line: line)
        }
    }
}

private final class JavaScriptLanguageProvider: TreeSitterLanguageProvider {
    private let language: TreeSitterLanguage

    init(language: TreeSitterLanguage) {
        self.language = language
    }

    func treeSitterLanguage(named languageName: String) -> TreeSitterLanguage? {
        languageName == "javascript" ? language : nil
    }
}

private final class CancellingHighlightTheme: Theme {
    var onHighlight: (() -> Void)?
    let font = DefaultTheme.shared.font
    let textColor = DefaultTheme.shared.textColor
    let gutterBackgroundColor = DefaultTheme.shared.gutterBackgroundColor
    let gutterHairlineColor = DefaultTheme.shared.gutterHairlineColor
    let lineNumberColor = DefaultTheme.shared.lineNumberColor
    let lineNumberFont = DefaultTheme.shared.lineNumberFont
    let selectedLineBackgroundColor = DefaultTheme.shared.selectedLineBackgroundColor
    let selectedLinesLineNumberColor = DefaultTheme.shared.selectedLinesLineNumberColor
    let selectedLinesGutterBackgroundColor = DefaultTheme.shared.selectedLinesGutterBackgroundColor
    let invisibleCharactersColor = DefaultTheme.shared.invisibleCharactersColor
    let pageGuideHairlineColor = DefaultTheme.shared.pageGuideHairlineColor
    let pageGuideBackgroundColor = DefaultTheme.shared.pageGuideBackgroundColor
    let markedTextBackgroundColor = DefaultTheme.shared.markedTextBackgroundColor

    func textColor(for highlightName: String) -> UIColor? {
        let callback = onHighlight
        onHighlight = nil
        callback?()
        return .red
    }
}
