#if canImport(AppKit)
import AppKit
import RunestoneEngine
@testable import RunestoneAppKit
import XCTest

final class ReadOnlyDocumentViewTests: XCTestCase {
    private let font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)

    func testDistantViewportUsesSnapshotAndDrawsText() throws {
        let source = NSMutableAttributedString(string: (0..<200).map { "line \($0)" }.joined(separator: "\n"),
                                               attributes: [.font: font, .foregroundColor: NSColor.black])
        let (scroll, view) = makeView(source, width: 160, height: 80)
        source.replaceCharacters(in: NSRange(location: 0, length: source.length), with: "changed")
        let untouched = view.manager.line(atRow: 30)
        let initialHeight = untouched.data.lineHeight
        let destination = view.manager.line(atRow: 170)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: destination.yPosition))
        let result = try XCTUnwrap(view.visibleLayout)
        XCTAssertTrue(result.lines.contains { $0.line === destination })
        XCTAssertEqual(untouched.data.lineHeight, initialHeight, accuracy: 0.001)
        XCTAssertNotEqual(view.manager.stringView.string as String, source.string)
        let image = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 160, pixelsHigh: 80,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: image))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.cgContext.translateBy(x: 0, y: CGFloat(image.pixelsHigh) + scroll.contentView.bounds.minY)
        graphics.cgContext.scaleBy(x: 1, y: -1)
        view.draw(scroll.contentView.bounds)
        NSGraphicsContext.restoreGraphicsState()
        let bytes = try XCTUnwrap(image.bitmapData)
        XCTAssertTrue((0..<image.pixelsHigh).contains { y in
            (0..<image.pixelsWide).contains { x in bytes[y * image.bytesPerRow + x * 4 + 3] != 0 }
        })
    }

    func testIncrementalEditInvalidatesStaleLayoutsAndKeepsUnchangedLines() throws {
        let (scroll, view) = makeView(NSAttributedString(string: "first\nsecond\nlast", attributes: [.font: font]),
                                      width: 180, height: 100)
        let previous = try XCTUnwrap(view.visibleLayout)
        let first = try XCTUnwrap(previous.lines.first)
        let last = view.manager.line(atRow: 2)
        let replacement = NSAttributedString(string: "longer\nnew", attributes: [.font: font])
        XCTAssertTrue(view.replaceContent(in: NSRange(location: 0, length: 12), with: replacement))
        XCTAssertEqual(view.manager.stringView.string as String, view.content.string)
        XCTAssertTrue(view.manager.lastLine === last)
        XCTAssertTrue(first.controller.layout(.toLocation(1)).isEmpty)
        let current = try XCTUnwrap(view.visibleLayout)
        XCTAssertTrue(current.lines.contains { $0.line === last })
        XCTAssertEqual(current.viewport.minY, scroll.contentView.bounds.minY, accuracy: 0.01)
    }

    func testMalformedAttributedReplacementStaysSynchronized() throws {
        let malformed = NSMutableAttributedString(string: "😀", attributes: [.font: font])
        malformed.mutableString.deleteCharacters(in: NSRange(location: 0, length: 1))
        guard malformed.mutableString.length == 1 && malformed.mutableString.character(at: 0) == 0xDE00 else {
            throw XCTSkip("Foundation repaired the malformed UTF-16 input")
        }
        func assertSynchronized(_ view: ReadOnlyDocumentView) {
            let stored = NSMutableAttributedString(attributedString: view.content).mutableString
            XCTAssertEqual(stored.length, view.manager.stringView.string.length)
            guard stored.length == view.manager.stringView.string.length else { return }
            for index in 0..<stored.length {
                XCTAssertEqual(stored.character(at: index), view.manager.stringView.string.character(at: index))
            }
        }
        let view = ReadOnlyDocumentView(content: malformed)
        assertSynchronized(view)
        view.setContent(NSAttributedString(string: ""))
        XCTAssertTrue(view.replaceContent(in: NSRange(location: 0, length: 0), with: malformed))
        assertSynchronized(view)
        view.setContent(malformed)
        assertSynchronized(view)
    }

    func testEmptyIncrementalEditInsideCRLFIsANoOp() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "a\r\nb"))
        let first = view.manager.firstLine
        let last = view.manager.lastLine
        XCTAssertTrue(view.replaceContent(in: NSRange(location: 2, length: 0), with: NSAttributedString(string: "")))
        XCTAssertTrue(view.manager.firstLine === first)
        XCTAssertTrue(view.manager.lastLine === last)
        XCTAssertEqual(view.manager.lineCount, 2)
        XCTAssertEqual(view.content.string, "a\r\nb")
    }

    func testResizeKeepsVisibleTextAndRewrapsIt() throws {
        let lines = (0..<120).map { "\($0): " + String(repeating: "long wrapped text ", count: 12) }
        let (scroll, view) = makeView(NSAttributedString(string: lines.joined(separator: "\n"), attributes: [.font: font]),
                                      width: 180, height: 80)
        let target = view.manager.line(atRow: 100)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: target.yPosition))
        view.updateViewport()
        let before = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first)
        let location = before.documentRange.location
        let screenY = before.frame.minY - scroll.contentView.bounds.minY
        scroll.setFrameSize(NSSize(width: 300, height: 80))
        scroll.tile()
        view.updateViewport()
        let result = try XCTUnwrap(view.visibleLayout)
        let containing = result.lines.flatMap(\.placements).first {
            $0.documentRange.location <= location && location < $0.documentRange.location + $0.documentRange.length
        }
        let placement = try XCTUnwrap(containing)
        XCTAssertEqual(placement.frame.minY - result.viewport.minY, screenY, accuracy: 1)
        XCTAssertGreaterThan(placement.documentRange.length, before.documentRange.length)
        XCTAssertEqual(view.frame.width, scroll.contentView.bounds.width, accuracy: 0.001)
    }

    func testUpwardScrollKeepsPreviouslyVisibleLineAnchored() throws {
        let text = String(repeating: "wrapped words ", count: 40) + "\nanchor\ntail"
        let (scroll, view) = makeView(NSAttributedString(string: text, attributes: [.font: font]), width: 100, height: 20)
        let anchor = view.manager.line(atRow: 1)
        view.manager.setHeight(of: view.manager.firstLine, to: 16)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: anchor.yPosition + 10))
        view.updateViewport()
        let oldY = anchor.yPosition
        let requestedY = scroll.contentView.bounds.minY - 5
        scroll.contentView.scroll(to: NSPoint(x: 0, y: requestedY))
        view.updateViewport()
        XCTAssertGreaterThan(anchor.yPosition, oldY)
        XCTAssertEqual(scroll.contentView.bounds.minY, requestedY + anchor.yPosition - oldY, accuracy: 1)
    }

    func testDisplayConfigurationInsetsTextAndConstrainsWrappingWithoutMutatingContent() throws {
        let text = NSAttributedString(string: String(repeating: "word ", count: 30), attributes: [.font: font])
        let (scroll, view) = makeView(text, width: 320, height: 100)
        let revision = view.contentRevision
        let content = view.content
        view.displayConfiguration = RunestoneEditorDisplayConfiguration(
            showsLineNumbers: true,
            minimumGutterCharacterCount: 4,
            maximumContentWidthColumn: 12,
            characterWidth: 8
        )
        view.updateViewport()
        let layout = try XCTUnwrap(view.visibleLayout)
        let placements = layout.lines.flatMap(\.placements)
        XCTAssertGreaterThan(try XCTUnwrap(placements.first).frame.minX, 0)
        XCTAssertTrue(placements.allSatisfy { $0.frame.width <= 96.5 })
        XCTAssertEqual(view.contentRevision, revision)
        XCTAssertTrue(view.content.isEqual(to: content))
        XCTAssertEqual(view.frame.width, scroll.contentView.bounds.width, accuracy: 0.001)
    }

    func testDisplaySelectionAndPresentationOptionsDoNotChangeInputSnapshot() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "one\ttwo\nthree", attributes: [.font: font]))
        let revision = view.contentRevision
        view.updateDisplaySelection(NSRange(location: 4, length: 3))
        view.displayConfiguration = RunestoneEditorDisplayConfiguration(
            showsSelectedLines: true, showsTabs: true, showsLineBreaks: true, pageGuideColumn: 8,
            characterWidth: 8
        )
        XCTAssertEqual(view.content.string, "one\ttwo\nthree")
        XCTAssertEqual(view.contentRevision, revision)
    }

    func testLineNumberGutterReflowsWhenLineCountNeedsAnotherDigit() throws {
        let content = (1...9).map(String.init).joined(separator: "\n")
        let (_, view) = makeView(NSAttributedString(string: content, attributes: [.font: font]), width: 200, height: 200)
        view.displayConfiguration = RunestoneEditorDisplayConfiguration(
            showsLineNumbers: true,
            minimumGutterCharacterCount: 1
        )
        view.updateViewport()
        let initialX = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first?.frame.minX)

        XCTAssertTrue(view.replaceContent(
            in: NSRange(location: view.content.length, length: 0),
            with: NSAttributedString(string: "\n10", attributes: [.font: font])
        ))
        view.updateViewport()

        let expandedX = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first?.frame.minX)
        XCTAssertGreaterThan(expandedX, initialX)
    }

    func testFragmentLineHighlightOnlyCoversSelectedWrappedFragment() throws {
        let text = NSAttributedString(string: String(repeating: "word ", count: 30), attributes: [.font: font])
        let (_, view) = makeView(text, width: 100, height: 200)
        view.displayConfiguration = RunestoneEditorDisplayConfiguration(
            showsSelectedLines: true,
            selectedLineHighlightGranularity: .lineFragment
        )
        view.updateDisplaySelection(NSRange(location: 2, length: 0))
        view.updateViewport()
        let layout = try XCTUnwrap(view.visibleLayout)

        XCTAssertGreaterThan(try XCTUnwrap(layout.lines.first?.placements.count), 1)
        XCTAssertEqual(view.selectedLineHighlightRects(in: layout).count, 1)
    }

    func testTypographyAndOverscrollArePresentationOnly() throws {
        let text = NSAttributedString(
            string: (0..<40).map { "\($0) " + String(repeating: "wide text ", count: 12) }.joined(separator: "\n"),
            attributes: [.font: font]
        )
        let (scroll, view) = makeView(text, width: 140, height: 80)
        let revision = view.contentRevision
        let original = view.content
        let initial = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first)

        view.displayConfiguration = RunestoneEditorDisplayConfiguration(
            isLineWrappingEnabled: false,
            lineHeightMultiplier: 1.5,
            kern: 2,
            verticalOverscrollFactor: 0.5,
            horizontalOverscrollFactor: 0.5
        )
        view.updateViewport()
        let presented = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first)

        XCTAssertEqual(presented.frame.height, initial.frame.height * 1.5, accuracy: 0.5)
        XCTAssertGreaterThan(presented.frame.width, initial.frame.width)
        XCTAssertGreaterThan(view.frame.width, scroll.contentView.bounds.width)
        XCTAssertGreaterThan(view.frame.height, view.manager.contentHeight)
        XCTAssertEqual(view.contentRevision, revision)
        XCTAssertTrue(view.content.isEqual(to: original))
        XCTAssertNil(view.content.attribute(.kern, at: 0, effectiveRange: nil))
    }

    private func makeView(_ text: NSAttributedString, width: CGFloat, height: CGFloat) -> (NSScrollView, ReadOnlyDocumentView) {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        let view = ReadOnlyDocumentView(snapshot: text, fallbackHeight: 16)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        return (scroll, view)
    }
}
#endif
