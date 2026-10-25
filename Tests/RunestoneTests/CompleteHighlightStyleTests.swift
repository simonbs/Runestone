@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

final class CompleteHighlightStyleTests: XCTestCase {
    func testCompleteStyleRestoresDefaultsWithinEnclosingCaptureAndPreservesWeight() throws {
        let theme = CompleteCaptureTheme()
        let outerDescriptor = try XCTUnwrap(theme.font.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]))
        let outerFont = UIFont(descriptor: outerDescriptor, size: 17)
        let preciseFont = UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold)
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 3
        theme.styles = [
            "container": HighlightStyle(textColor: .red, font: outerFont, backgroundColor: .yellow, shadow: shadow),
            "string": HighlightStyle(),
            "number": HighlightStyle(font: preciseFont)
        ]
        let highlighter = StringSyntaxHighlighter(theme: theme, language: jsonLanguage())
        let text = "{\"Grøn 😀\": 42}"
        let output = highlighter.syntaxHighlight(text)
        XCTAssertEqual(output.string, text)
        let source = text as NSString
        XCTAssertEqual(output.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, outerFont)
        XCTAssertEqual(output.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? UIColor, .yellow)
        for range in [source.range(of: "\"Grøn 😀\""), source.range(of: "42")] {
            output.enumerateAttributes(in: range) { attributes, _, _ in
                XCTAssertEqual(attributes[.foregroundColor] as? UIColor, theme.textColor)
                XCTAssertNil(attributes[.backgroundColor])
                XCTAssertNil(attributes[.shadow])
                XCTAssertEqual(attributes[.isItalic] as? Bool, false)
            }
        }
        XCTAssertEqual(output.attribute(.font, at: source.range(of: "Grøn").location, effectiveRange: nil) as? UIFont, theme.font)
        XCTAssertEqual(output.attribute(.isBold, at: source.range(of: "Grøn").location, effectiveRange: nil) as? Bool, false)
        XCTAssertEqual(output.attribute(.font, at: source.range(of: "42").location, effectiveRange: nil) as? UIFont, preciseFont)
        XCTAssertEqual(theme.individualCallbackCount, 0, "Complete styles must not also invoke the individual callbacks.")
    }

    func testFontOnlyCompleteStyleIsAppliedWithoutForeground() {
        let theme = CompleteCaptureTheme()
        let font = UIFont.italicSystemFont(ofSize: 21)
        theme.styles = ["string": HighlightStyle(font: font)]
        let result = StringSyntaxHighlighter(theme: theme, language: jsonLanguage()).syntaxHighlight("\"text\"")
        XCTAssertEqual(result.attribute(.font, at: 1, effectiveRange: nil) as? UIFont, font)
        XCTAssertEqual(result.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? UIColor, theme.textColor)
    }

    func testExistingThemeUsesIndividualCallbacksIncludingTraitsOnlyCaptures() throws {
        let theme = ExistingCaptureTheme()
        let erasedTheme: Theme = theme
        XCTAssertNil(erasedTheme.highlightStyle(for: "string"))
        let result = StringSyntaxHighlighter(theme: theme, language: jsonLanguage()).syntaxHighlight("[\"text\", 42]")
        let stringFont = try XCTUnwrap(result.attribute(.font, at: 2, effectiveRange: nil) as? UIFont)
        XCTAssertTrue(stringFont.fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertEqual(result.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? UIColor, theme.textColor)
        XCTAssertEqual(result.attribute(.foregroundColor, at: 9, effectiveRange: nil) as? UIColor, .blue)
    }

    func testNilCompleteStyleFallsBackForThatCapture() {
        let theme = CompleteCaptureTheme()
        theme.styles = ["string": HighlightStyle(textColor: .red)]
        let result = StringSyntaxHighlighter(theme: theme, language: jsonLanguage()).syntaxHighlight("[\"text\", 42]")
        XCTAssertEqual(result.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? UIColor, .red)
        XCTAssertEqual(result.attribute(.foregroundColor, at: 9, effectiveRange: nil) as? UIColor, .blue)
        XCTAssertGreaterThan(theme.individualCallbackCount, 0)
    }

    func testSpecializedCaptureResetsCompleteStyleOnSameRange() {
        let theme = CompleteCaptureTheme()
        theme.styles = [
            "string": HighlightStyle(textColor: .red, font: .italicSystemFont(ofSize: 17), backgroundColor: .yellow),
            "string.special": HighlightStyle()
        ]
        let language = TreeSitterLanguage(tree_sitter_json(), highlightsQuery: .init(string: """
        (string) @string.special
        (string) @string
        """))
        let result = StringSyntaxHighlighter(theme: theme, language: language).syntaxHighlight("\"text\"")
        XCTAssertEqual(result.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? UIColor, theme.textColor)
        XCTAssertEqual(result.attribute(.font, at: 1, effectiveRange: nil) as? UIFont, theme.font)
        XCTAssertNil(result.attribute(.backgroundColor, at: 1, effectiveRange: nil))
    }

    func testMultilineCaptureIsClippedAndThemeSwitchDoesNotRetainBackground() {
        let theme = CompleteCaptureTheme()
        theme.styles = ["container": HighlightStyle(backgroundColor: .yellow), "string": HighlightStyle()]
        let text = "{\n\"key\": 42\n}"
        let language = jsonLanguage()
        let mode = LanguageModeFactory.languageMode(language: language, text: text)
        mode.parse(text as NSString)
        let highlighter = mode.createLineSyntaxHighlighter()
        highlighter.theme = theme
        let localText = "\"key\": 42"
        let attributes: [NSAttributedString.Key: Any] = [.font: theme.font, .foregroundColor: theme.textColor]
        let local = NSMutableAttributedString(string: localText, attributes: attributes)
        highlighter.syntaxHighlight(LineSyntaxHighlighterInput(
            attributedString: local,
            byteRange: ByteRange(utf16Range: NSRange(location: 2, length: local.length))))
        XCTAssertNil(local.attribute(.backgroundColor, at: 1, effectiveRange: nil))
        XCTAssertEqual(local.attribute(.backgroundColor, at: 5, effectiveRange: nil) as? UIColor, .yellow)
        highlighter.theme = ExistingCaptureTheme()
        local.setAttributes(attributes, range: NSRange(location: 0, length: local.length))
        highlighter.syntaxHighlight(LineSyntaxHighlighterInput(
            attributedString: local,
            byteRange: ByteRange(utf16Range: NSRange(location: 2, length: local.length))))
        XCTAssertNil(local.attribute(.backgroundColor, at: 5, effectiveRange: nil))
    }

    func testCancelledHighlightCannotApplyPreviousThemeAfterSwitch() {
        let text = "\"text\""
        let stringView = StringView(string: text)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let mode = TreeSitterInternalLanguageMode(
            language: jsonLanguage().internalLanguage, languageProvider: nil,
            stringView: stringView, lineManager: lineManager)
        mode.parse(text as NSString)
        let queue = OperationQueue()
        queue.isSuspended = true
        let highlighter = TreeSitterSyntaxHighlighter(stringView: stringView, languageMode: mode, operationQueue: queue)
        let previousTheme = CompleteCaptureTheme()
        previousTheme.styles = ["string": HighlightStyle(textColor: .red, backgroundColor: .yellow)]
        highlighter.theme = previousTheme
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.black, .font: previousTheme.font]
        let cancelledString = NSMutableAttributedString(string: text, attributes: attributes)
        let newString = NSMutableAttributedString(string: text, attributes: attributes)
        let range = ByteRange(utf16Range: NSRange(location: 0, length: cancelledString.length))
        highlighter.syntaxHighlight(LineSyntaxHighlighterInput(attributedString: cancelledString, byteRange: range)) { result in
            if case .success = result {
                XCTFail("A cancelled operation must not apply its attributes.")
            }
        }
        highlighter.cancel()
        let nextTheme = CompleteCaptureTheme()
        nextTheme.styles = ["string": HighlightStyle(textColor: .blue)]
        highlighter.theme = nextTheme
        let applied = expectation(description: "Next theme is applied")
        highlighter.syntaxHighlight(LineSyntaxHighlighterInput(attributedString: newString, byteRange: range)) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected highlighting failure: \(error)")
            }
            applied.fulfill()
        }
        queue.isSuspended = false
        wait(for: [applied], timeout: 2)
        XCTAssertEqual(cancelledString.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? UIColor, .black)
        XCTAssertNil(cancelledString.attribute(.backgroundColor, at: 1, effectiveRange: nil))
        XCTAssertEqual(newString.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? UIColor, .blue)
        XCTAssertNil(newString.attribute(.backgroundColor, at: 1, effectiveRange: nil))
    }

    private func jsonLanguage() -> TreeSitterLanguage {
        TreeSitterLanguage(tree_sitter_json(), highlightsQuery: .init(string: """
        (object) @container
        (string) @string
        (number) @number
        """))
    }
}

private protocol CaptureThemeDefaults: Theme {}

private extension CaptureThemeDefaults {
    var font: UIFont { .monospacedSystemFont(ofSize: 17, weight: .regular) }
    var textColor: UIColor { .black }
    var gutterBackgroundColor: UIColor { .white }
    var gutterHairlineColor: UIColor { .gray }
    var lineNumberColor: UIColor { .gray }
    var lineNumberFont: UIFont { font }
    var selectedLineBackgroundColor: UIColor { .clear }
    var selectedLinesLineNumberColor: UIColor { .black }
    var selectedLinesGutterBackgroundColor: UIColor { .white }
    var invisibleCharactersColor: UIColor { .gray }
    var pageGuideHairlineColor: UIColor { .gray }
    var pageGuideBackgroundColor: UIColor { .white }
    var markedTextBackgroundColor: UIColor { .yellow }
}

private final class ExistingCaptureTheme: CaptureThemeDefaults {
    func textColor(for highlightName: String) -> UIColor? {
        highlightName == "number" ? .blue : nil
    }

    func fontTraits(for highlightName: String) -> FontTraits {
        highlightName == "string" ? .italic : []
    }
}

private final class CompleteCaptureTheme: CaptureThemeDefaults {
    var styles: [String: HighlightStyle] = [:]
    var individualCallbackCount = 0

    func highlightStyle(for highlightName: String) -> HighlightStyle? {
        styles[highlightName]
    }

    func textColor(for highlightName: String) -> UIColor? {
        individualCallbackCount += 1
        return highlightName == "number" ? .blue : nil
    }
}
