#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class GutterTextPaddingTests: XCTestCase {
    func testLeadingPaddingMatchesHiddenGutterForLineNumbersAndFolding() throws {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 240, height: 200))
        let view = ReadOnlyDocumentView(content: NSAttributedString(
            string: String(repeating: "wrapped text ", count: 5) + "\n\nlast",
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)]))
        scroll.documentView = view
        scroll.tile()
        view.updateDisplaySelection(NSRange(location: 0, length: 0))
        view.displayConfiguration.horizontalTextPadding = 10
        view.updateViewport()
        let hiddenGutterTextX = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first).frame.minX
        XCTAssertEqual(hiddenGutterTextX, 10, accuracy: 0.01)

        for wraps in [true, false] {
            for (numbers, folding) in [(true, false), (false, true), (true, true)] {
                var configuration = view.displayConfiguration
                configuration.isLineWrappingEnabled = wraps
                configuration.showsLineNumbers = numbers
                configuration.isCodeFoldingEnabled = folding
                configuration.showsSelectedLines = true
                view.displayConfiguration = configuration
                view.updateViewport()
                let gutter = try XCTUnwrap(view.subviews.last)
                let layout = try XCTUnwrap(view.visibleLayout)
                let placements = try XCTUnwrap(layout.lines.first).placements
                XCTAssertFalse(placements.isEmpty)
                for placement in placements {
                    XCTAssertEqual(placement.frame.minX - gutter.frame.maxX, hiddenGutterTextX, accuracy: 0.01)
                }
                let emptyLine = try XCTUnwrap(layout.lines.first { $0.line.data.length == 0 })
                let caret = view.emptyLineCaretRect(y: emptyLine.line.yPosition,
                                                   rowHeight: emptyLine.line.data.lineHeight, width: 1)
                XCTAssertEqual(caret.minX - gutter.frame.maxX, hiddenGutterTextX, accuracy: 0.01)
                let highlight = try XCTUnwrap(view.selectedLineHighlightRects(in: layout).first)
                XCTAssertEqual(highlight.minX, gutter.frame.maxX, accuracy: 0.01,
                               "The selected row must cover the padding between the gutter and text")
            }
        }

        view.displayConfiguration.showsLineNumbers = false
        view.displayConfiguration.isCodeFoldingEnabled = false
        view.updateViewport()
        XCTAssertEqual(try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first).frame.minX,
                       hiddenGutterTextX, accuracy: 0.01)
    }
}
#endif
