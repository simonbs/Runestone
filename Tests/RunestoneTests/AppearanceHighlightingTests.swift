import CoreText
@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

@MainActor
final class AppearanceHighlightingTests: XCTestCase {
    func testAsyncResultDistinguishesAppearanceFromFinalFontChanges() throws {
        let theme = AppearanceTheme()
        theme.styles = ["string": HighlightStyle(textColor: .red, backgroundColor: .yellow)]
        XCTAssertFalse(try highlight(theme: theme).isSizingInvalid)
        theme.styles = ["string": HighlightStyle(font: .systemFont(ofSize: 30))]
        XCTAssertTrue(try highlight(theme: theme).isSizingInvalid)
        // Both captures cover the same text. Only their final effective font matters.
        theme.styles = ["string": HighlightStyle(font: .italicSystemFont(ofSize: 25)),
                        "string.special": HighlightStyle(textColor: .blue)]
        XCTAssertFalse(try highlight(theme: theme, query: "(string) @string.special\n(string) @string").isSizingInvalid)
    }

    func testRefreshPreservesPartialWrapsAndContinuesWithNewAppearance() throws {
        try checkRefresh(partial: true)
    }

    func testRefreshOfFinishedLineUpdatesDrawingAndPreservesGeometry() throws {
        try checkRefresh(partial: false)
    }

    private func checkRefresh(partial: Bool) throws {
        let text = String(repeating: "office cafe\u{301} 😀 אבג العربية\tend" + String(repeating: " ", count: 40), count: 12)
        let initial = NSMutableAttributedString(string: text)
        DefaultStringAttributes(textColor: .black, font: .systemFont(ofSize: 18), kern: 0, tabWidth: 40).apply(to: initial)
        let typesetter = makeTypesetter(initial)
        if partial {
            typesetter.typesetLineFragments(toLocation: 1, additionalLineFragmentCount: 1)
            XCTAssertFalse(typesetter.isFinishedTypesetting)
        } else {
            typesetter.typesetLineFragments(toLocation: initial.length)
            XCTAssertTrue(typesetter.isFinishedTypesetting)
        }
        let previous = typesetter.lineFragments
        let previousLength = typesetter.typesetLength
        let previousWidth = typesetter.maximumLineWidth
        let previousEstimate = typesetter.bestGuessNumberOfLineFragments
        let originalPixels = try previous.map { try pixels($0) }
        let styled = appearanceString(initial)
        let refreshed = typesetter.refreshAppearance(styled)
        XCTAssertEqual(refreshed.count, previous.count)
        XCTAssertEqual(typesetter.typesetLength, previousLength)
        XCTAssertEqual(typesetter.maximumLineWidth, previousWidth)
        XCTAssertEqual(typesetter.bestGuessNumberOfLineFragments, previousEstimate)
        XCTAssertEqual(typesetter.isFinishedTypesetting, !partial)
        for (before, after) in zip(previous, refreshed) {
            assertGeometry(before, after)
        }
        XCTAssertNotEqual(try refreshed.map { try pixels($0) }, originalPixels,
                          "Refreshing attributes must replace the actual drawing objects, not only preserve wraps.")
        typesetter.typesetLineFragments(toLocation: styled.length)
        let fresh = makeTypesetter(styled)
        fresh.typesetLineFragments(toLocation: styled.length)
        XCTAssertTrue(typesetter.isFinishedTypesetting)
        XCTAssertEqual(typesetter.lineFragments.count, fresh.lineFragments.count)
        XCTAssertEqual(typesetter.maximumLineWidth, fresh.maximumLineWidth)
        XCTAssertTrue(typesetter.lineFragments.contains { $0.hiddenLength > 0 }, "Exercise hidden wrap whitespace.")
        for (actual, expected) in zip(typesetter.lineFragments, fresh.lineFragments) {
            assertGeometry(actual, expected)
            XCTAssertEqual(try pixels(actual), try pixels(expected),
                           "Refreshed and continued fragments must render identically to fresh styled typesetting.")
        }
    }

    private func appearanceString(_ initial: NSAttributedString) -> NSAttributedString {
        let styled = NSMutableAttributedString(attributedString: initial)
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.blue
        shadow.shadowOffset = CGSize(width: 1, height: 1)
        shadow.shadowBlurRadius = 1
        styled.addAttributes([.foregroundColor: UIColor.red, .backgroundColor: UIColor.yellow, .shadow: shadow],
                             range: NSRange(location: 0, length: styled.length))
        // Split a ligature candidate and directional/composed runs without splitting
        // UTF-16 surrogate pairs. Appearance run boundaries must not stale caret data.
        let source = initial.string as NSString
        styled.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 2, length: 1))
        let arabic = source.range(of: "العربية")
        styled.addAttribute(.foregroundColor, value: UIColor.green,
                            range: NSRange(location: arabic.location + 1, length: 2))
        styled.addAttribute(.backgroundColor, value: UIColor.cyan, range: source.range(of: "cafe\u{301}"))
        styled.removeAttribute(.shadow, range: source.range(of: "😀"))
        return styled
    }

    private func assertGeometry(_ actual: LineFragment, _ expected: LineFragment,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.id, expected.id, file: file, line: line)
        XCTAssertEqual(actual.visibleRange, expected.visibleRange, file: file, line: line)
        XCTAssertEqual(actual.hiddenLength, expected.hiddenLength, file: file, line: line)
        XCTAssertEqual(actual.baseSize, expected.baseSize, file: file, line: line)
        XCTAssertEqual(actual.scaledSize, expected.scaledSize, file: file, line: line)
        XCTAssertEqual(actual.yPosition, expected.yPosition, file: file, line: line)
        XCTAssertEqual(actual.descent, expected.descent, file: file, line: line)
        for location in actual.visibleRange.location...actual.visibleRange.upperBound {
            XCTAssertEqual(CTLineGetOffsetForStringIndex(actual.line, location, nil),
                           CTLineGetOffsetForStringIndex(expected.line, location, nil), accuracy: 0.001,
                           file: file, line: line)
        }
    }

    private func makeTypesetter(_ string: NSAttributedString) -> LineTypesetter {
        let typesetter = LineTypesetter(lineID: "appearance")
        typesetter.constrainingWidth = 175
        typesetter.lineFragmentHeightMultiplier = 1.2
        typesetter.prepareToTypeset(string)
        return typesetter
    }

    private func highlight(theme: AppearanceTheme, query: String = "(string) @string") throws -> LineSyntaxHiglighterSetAttributesResult {
        let text = "\"text\""
        let language = TreeSitterLanguage(tree_sitter_json(), highlightsQuery: .init(string: query))
        let mode = LanguageModeFactory.languageMode(language: language, text: text)
        mode.parse(text as NSString)
        let highlighter = mode.createLineSyntaxHighlighter()
        highlighter.theme = theme
        let string = NSMutableAttributedString(string: text, attributes: [.font: theme.font, .foregroundColor: theme.textColor])
        let input = LineSyntaxHighlighterInput(
            attributedString: string,
            byteRange: ByteRange(utf16Range: NSRange(location: 0, length: string.length)))
        let completed = expectation(description: "Highlighting applied")
        var outcome: Result<LineSyntaxHiglighterSetAttributesResult, Error>?
        highlighter.syntaxHighlight(input) { result in
            outcome = result
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
        return try XCTUnwrap(outcome).get()
    }

    private func pixels(_ fragment: LineFragment) throws -> Data {
        let width = 190
        let height = Int(ceil(fragment.scaledSize.height)) + 4
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        LineFragmentRenderer(lineFragment: fragment, invisibleCharacterConfiguration: .init())
            .draw(to: context, inCanvasOfSize: CGSize(width: width, height: height))
        return Data(bytes: try XCTUnwrap(context.data), count: width * height * 4)
    }
}

private final class AppearanceTheme: Theme {
    var styles: [String: HighlightStyle] = [:]
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

    func highlightStyle(for highlightName: String) -> HighlightStyle? { styles[highlightName] }
    func textColor(for highlightName: String) -> UIColor? { nil }
}
