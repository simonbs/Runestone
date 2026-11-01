import CoreText
@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

@MainActor
final class LayoutHighlightingTests: XCTestCase {
    private let source = "[\"target " + String(repeating: "alpha beta gamma ", count: 20) + "\", 42]"

    func testLayoutSettingsKeepRenderedSyntaxWithoutHighlightingAgain() throws {
        let theme = LayoutCountingTheme()
        let (view, input) = try makeView(theme: theme)
        let originalSelection = view.selectedRange
        let lookups = theme.lookupCount
        XCTAssertGreaterThan(lookups, 0)
        try assertSyntax(in: view)

        let changes: [(String, () -> Void)] = [
            ("wrapping on", { view.isLineWrappingEnabled = true }),
            ("line numbers on", { view.showLineNumbers = true }),
            ("wider gutter", { view.gutterMinimumCharacterCount = 6 }),
            ("line numbers off", { view.showLineNumbers = false }),
            ("line height", { view.lineHeightMultiplier = 1.5 }),
            ("character wrapping", { view.lineBreakMode = .byCharWrapping }),
            ("narrower viewport", { view.frame.size.width = 240 }),
            ("show spaces", { view.showSpaces = true }),
            ("show line breaks", { view.showLineBreaks = true }),
            ("wrapping off", { view.isLineWrappingEnabled = false })
        ]
        for (name, change) in changes {
            change()
            settle(view, input: input)
            // Do not yield to the run loop: a later async recolor would conceal
            // the plain-text frame that originally appeared during these changes.
            try assertSyntax(in: view, message: name)
            XCTAssertEqual(theme.lookupCount, lookups, "\(name) must reuse the existing syntax attributes")
            XCTAssertEqual(view.text, source, name)
            XCTAssertEqual(view.selectedRange, originalSelection, name)
        }
    }

    func testRetainedSyntaxStillReflowsWrappingWidthAndLineHeight() throws {
        let theme = LayoutCountingTheme()
        let (view, input) = try makeView(theme: theme)
        let selection = view.selectedRange
        let unwrappedHeight = input.lineManager.firstLine.data.lineHeight
        view.isLineWrappingEnabled = true
        settle(view, input: input)
        let wrappedHeight = input.lineManager.firstLine.data.lineHeight
        XCTAssertGreaterThan(wrappedHeight, unwrappedHeight * 2)
        view.frame.size.width = 220
        settle(view, input: input)
        let narrowHeight = input.lineManager.firstLine.data.lineHeight
        XCTAssertGreaterThan(narrowHeight, wrappedHeight)
        view.lineHeightMultiplier = 1.75
        settle(view, input: input)
        XCTAssertEqual(input.lineManager.firstLine.data.lineHeight, narrowHeight * 1.75, accuracy: 0.5)
        try assertSyntax(in: view)
        XCTAssertEqual(view.text, source)
        XCTAssertEqual(view.selectedRange, selection)
    }

    func testThemeChangeStillReplacesSyntaxStyles() throws {
        let (view, input) = try makeView(theme: LayoutCountingTheme())
        try assertSyntax(in: view)
        let replacement = LayoutCountingTheme(stringColor: .purple, numberColor: .orange)
        view.theme = replacement
        input.layoutLines(toLocation: source.utf16.count)
        settle(view, input: input)
        XCTAssertGreaterThan(replacement.lookupCount, 0)
        try assertSyntax(in: view, stringColor: .purple, numberColor: .orange)
        XCTAssertEqual(view.text, source)
    }

    func testLanguageChangeStillClearsPreviousSyntaxStyles() throws {
        let (view, input) = try makeView(theme: LayoutCountingTheme())
        let selection = view.selectedRange
        try assertSyntax(in: view)
        let changed = expectation(description: "Plain text language applied")
        view.setLanguageMode(PlainTextLanguageMode()) { finished in
            XCTAssertTrue(finished)
            changed.fulfill()
        }
        wait(for: [changed], timeout: 5)
        input.layoutLines(toLocation: source.utf16.count)
        settle(view, input: input)
        try assertSyntax(in: view, stringColor: .black, numberColor: .black)
        XCTAssertEqual(view.text, source)
        XCTAssertEqual(view.selectedRange, selection)
    }

    private func makeView(theme: LayoutCountingTheme) throws -> (TextView, TextInputView) {
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 380, height: 1_500))
        view.contentInsetAdjustmentBehavior = .never
        view.isAutomaticScrollEnabled = false
        view.isLineWrappingEnabled = false
        view.showLineNumbers = false
        let language = TreeSitterLanguage(tree_sitter_json(), highlightsQuery: .init(string: "(string) @string\n(number) @number"))
        view.setState(TextViewState(text: source, theme: theme, language: language))
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        settle(view, input: input)
        input.layoutLines(toLocation: source.utf16.count)
        view.selectedRange = NSRange(location: 4, length: 3)
        settle(view, input: input)
        return (view, input)
    }

    private func settle(_ view: TextView, input: TextInputView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        input.setNeedsLayout()
        input.layoutIfNeeded()
        view.layoutIfNeeded()
    }

    private func assertSyntax(in view: TextView, stringColor: UIColor = .red, numberColor: UIColor = .blue,
                              message: String = "", file: StaticString = #filePath, line: UInt = #line) throws {
        let text = source as NSString
        for (token, color) in [("target", stringColor), ("42", numberColor)] {
            let location = text.range(of: token).location
            let colors = renderedFragments(in: view).flatMap { fragment -> [UIColor] in
                guard let rendered = fragment.renderer?.lineFragment else {
                    return []
                }
                let local = location - fragment.documentLineLocation
                guard NSLocationInRange(local, rendered.visibleRange) else {
                    return []
                }
                return (CTLineGetGlyphRuns(rendered.line) as? [CTRun] ?? []).compactMap { run in
                    let range = CTRunGetStringRange(run)
                    guard local >= range.location, local < range.location + range.length else {
                        return nil
                    }
                    return (CTRunGetAttributes(run) as NSDictionary)[NSAttributedString.Key.foregroundColor] as? UIColor
                }
            }
            XCTAssertEqual(colors, [color], "\(message): actual drawn \(token) must retain its syntax color", file: file, line: line)
        }
    }

    private func renderedFragments(in view: UIView) -> [LineFragmentView] {
        view.subviews.flatMap { child -> [LineFragmentView] in
            if let fragment = child as? LineFragmentView {
                return fragment.isHidden || fragment.renderer == nil ? [] : [fragment]
            }
            return renderedFragments(in: child)
        }
    }
}

private final class LayoutCountingTheme: Theme {
    private(set) var lookupCount = 0
    private let stringColor: UIColor
    private let numberColor: UIColor
    let font = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
    let textColor = UIColor.black
    let gutterBackgroundColor = UIColor.white
    let gutterHairlineColor = UIColor.gray
    let lineNumberColor = UIColor.gray
    var lineNumberFont: UIFont { font }
    let selectedLineBackgroundColor = UIColor.clear
    let selectedLinesLineNumberColor = UIColor.black
    let selectedLinesGutterBackgroundColor = UIColor.white
    let invisibleCharactersColor = UIColor.gray
    let pageGuideHairlineColor = UIColor.gray
    let pageGuideBackgroundColor = UIColor.white
    let markedTextBackgroundColor = UIColor.yellow

    init(stringColor: UIColor = .red, numberColor: UIColor = .blue) {
        self.stringColor = stringColor
        self.numberColor = numberColor
    }

    func highlightStyle(for highlightName: String) -> HighlightStyle? {
        lookupCount += 1
        switch highlightName {
        case "string":
            return HighlightStyle(textColor: stringColor, font: .monospacedSystemFont(ofSize: 19, weight: .bold))
        case "number":
            return HighlightStyle(textColor: numberColor)
        default:
            return nil
        }
    }

    func textColor(for highlightName: String) -> UIColor? { nil }
}
