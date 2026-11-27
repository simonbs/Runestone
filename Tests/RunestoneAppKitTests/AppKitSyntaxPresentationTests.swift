#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import RunestoneSyntax
import TestTreeSitterLanguages
import XCTest

@MainActor
final class AppKitSyntaxPresentationTests: XCTestCase {
    func testFoldIndicatorTintPreservesCompactDisclosureDimensions() throws {
        for color in [NSColor.lightGray, .darkGray, .labelColor] {
            let image = try XCTUnwrap(SyntaxFoldIndicator.image(color: color))
            // A color-only configuration used to reset the symbol to the
            // default 10-by-14-point image despite the smaller requested size.
            XCTAssertLessThanOrEqual(image.size.width, 9)
            XCTAssertLessThanOrEqual(image.size.height, 12)
            XCTAssertGreaterThan(image.size.width, 4)
            XCTAssertGreaterThan(image.size.height, 6)
        }
    }

    func testSemanticStyleIsPresentationOnlyAndUsesDottedFallback() throws {
        let text = "{\"name\": 42}\n"
        let baseColor = NSColor.black
        let content = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: baseColor
        ])
        let highlighter = try RunestoneSyntaxHighlighter(language: RunestoneSyntaxLanguage(
            language: tree_sitter_json(),
            highlightsQuery: "(number) @number.special"))
        let fixture = makeFixture(content)
        fixture.view.applySyntaxConfiguration(RunestoneAppKitSyntaxConfiguration(
            highlighter: highlighter,
            styles: ["number": RunestoneAppKitSyntaxStyle(foregroundColor: .systemRed)]),
            prefersStyledFirstPaint: true)
        XCTAssertTrue(fixture.view.isWaitingForInitialSyntaxPaint)

        let numberRange = (text as NSString).range(of: "42")
        let styled = expectation(for: NSPredicate { _, _ in
            fixture.view.presentationAttributedSubstring(from: NSRange(location: 0, length: content.length))
                .attribute(.foregroundColor, at: numberRange.location, effectiveRange: nil) as? NSColor == .systemRed
        }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [styled], timeout: 3), .completed)

        XCTAssertFalse(fixture.view.isWaitingForInitialSyntaxPaint)
        XCTAssertEqual(fixture.view.content.attribute(.foregroundColor, at: numberRange.location,
                                                      effectiveRange: nil) as? NSColor, baseColor)
        XCTAssertEqual(fixture.view.content.string, text)
    }

    func testTypingKeepsSyntaxColorsAndFontsUntilTheNextParse() throws {
        let text = "[42,\n 123]\n"
        let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let syntaxFont = NSFont.monospacedSystemFont(ofSize: 19, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: baseFont, .foregroundColor: NSColor.black]
        let fixture = makeFixture(NSAttributedString(string: text, attributes: attributes))
        let highlighter = try RunestoneSyntaxHighlighter(language: RunestoneSyntaxLanguage(
            language: tree_sitter_json(), highlightsQuery: "(number) @number"))
        fixture.view.applySyntaxConfiguration(RunestoneAppKitSyntaxConfiguration(
            highlighter: highlighter, styles: ["number": .init(foregroundColor: .systemRed, font: syntaxFont)]))

        func presentedAttributes(at offset: Int) -> [NSAttributedString.Key: Any] {
            fixture.view.presentationAttributedSubstring(from: NSRange(location: offset, length: 1))
                .attributes(at: 0, effectiveRange: nil)
        }
        let styled = expectation(for: NSPredicate { _, _ in
            presentedAttributes(at: 1)[.foregroundColor] as? NSColor == .systemRed
        }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [styled], timeout: 3), .completed)

        XCTAssertTrue(fixture.view.replaceContent(in: NSRange(location: 2, length: 0),
                                                 with: NSAttributedString(string: "9", attributes: attributes)))
        // No main-loop turn has allowed the asynchronous parse to publish yet.
        for offset in [1, 2, 3, 7, 8, 9] {
            let styled = presentedAttributes(at: offset)
            XCTAssertEqual(styled[.foregroundColor] as? NSColor, .systemRed)
            XCTAssertEqual(styled[.font] as? NSFont, syntaxFont)
        }
    }

    func testFirstPaintFallsBackWhenSyntaxIsSlow() {
        let fixture = makeFixture(NSAttributedString(string: "let value = 42"))
        fixture.view.applySyntaxConfiguration(RunestoneAppKitSyntaxConfiguration(
            highlighter: RecordingSyntaxHighlighter(completesUpdates: false), styles: [:]),
            prefersStyledFirstPaint: true)
        XCTAssertTrue(fixture.view.isWaitingForInitialSyntaxPaint)
        let painting = expectation(for: NSPredicate { _, _ in
            !fixture.view.isWaitingForInitialSyntaxPaint
        }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [painting], timeout: 3), .completed)
    }

    func testLargeDocumentQueriesOnlyVisibleLogicalLines() {
        let line = "let value = 1234567890\n"
        let text = String(repeating: line, count: 20_000)
        let content = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ])
        let highlighter = RecordingSyntaxHighlighter()
        let fixture = makeFixture(content, height: 64)
        fixture.view.applySyntaxConfiguration(RunestoneAppKitSyntaxConfiguration(
            highlighter: highlighter, styles: [:]), prefersStyledFirstPaint: true)
        XCTAssertFalse(fixture.view.isWaitingForInitialSyntaxPaint)

        let queried = expectation(for: NSPredicate { _, _ in highlighter.lastCaptureRange != nil }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [queried], timeout: 3), .completed)
        let requested = try! XCTUnwrap(highlighter.lastCaptureRange)
        XCTAssertGreaterThan(requested.length, 0)
        XCTAssertLessThan(requested.length, content.length / 100)
        XCTAssertLessThanOrEqual(NSMaxRange(requested), content.length)
    }

    func testParsedFoldCollapsesBodyAndUnfoldRestoresRows() throws {
        let text = "{\n  \"value\": 1\n}\n"
        let content = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ])
        let highlighter = try RunestoneSyntaxHighlighter(language: RunestoneSyntaxLanguage(
            language: tree_sitter_json(), foldsQuery: "(object) @fold"))
        let fixture = makeFixture(content)
        var configuration = fixture.view.displayConfiguration
        configuration.isCodeFoldingEnabled = true
        fixture.view.displayConfiguration = configuration
        fixture.view.applySyntaxConfiguration(RunestoneAppKitSyntaxConfiguration(
            highlighter: highlighter, styles: [:]))

        let parsed = expectation(for: NSPredicate { _, _ in fixture.view.syntaxFoldRows == [0] }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [parsed], timeout: 3), .completed)
        XCTAssertTrue(fixture.view.toggleSyntaxFold(atRow: 0))
        XCTAssertTrue(fixture.view.isSyntaxFoldCollapsed(atRow: 0))
        XCTAssertTrue(fixture.view.manager.isLineHidden(1))
        XCTAssertTrue(fixture.view.manager.isLineHidden(2))
        fixture.view.unfoldAllSyntax()
        XCTAssertFalse(fixture.view.manager.isLineHidden(1))
        XCTAssertFalse(fixture.view.isSyntaxFoldCollapsed(atRow: 0))
        XCTAssertEqual(fixture.view.content.string, text)
    }

    private func makeFixture(_ content: NSAttributedString, height: CGFloat = 120)
        -> (scroll: NSScrollView, view: ReadOnlyDocumentView) {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: height))
        let view = ReadOnlyDocumentView(content: content)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        return (scroll, view)
    }
}

private final class RecordingSyntaxHighlighter: RunestoneSyntaxHighlighting, @unchecked Sendable {
    private let lock = NSLock()
    private var range: NSRange?

    private let completesUpdates: Bool

    init(completesUpdates: Bool = true) {
        self.completesUpdates = completesUpdates
    }

    var lastCaptureRange: NSRange? {
        lock.lock()
        defer { lock.unlock() }
        return range
    }

    func update(_ text: String,
                completion: (@Sendable (Result<Void, RunestoneSyntaxError>) -> Void)?) {
        if completesUpdates { completion?(.success(())) }
    }

    func captures(in range: NSRange,
                  completion: @escaping @Sendable (Result<[RunestoneSyntaxCapture], RunestoneSyntaxError>) -> Void) {
        lock.lock()
        self.range = range
        lock.unlock()
        completion(.success([]))
    }

    func folds(completion: @escaping @Sendable (Result<[RunestoneSyntaxFold], RunestoneSyntaxError>) -> Void) {
        completion(.success([]))
    }

    func cancel() {}
}
#endif
