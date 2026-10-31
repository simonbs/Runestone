#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneEngine
@testable import RunestoneAppKit
import XCTest

final class InputSelectionGeometryTests: XCTestCase {
    func testCaretAndSelectionUseCurrentDocumentCoordinates() throws {
        let (scroll, view) = makeView("hello world", width: 180, height: 80)
        let atStart = try XCTUnwrap(InputSelectionGeometry.geometry(selection: NSRange(location: 0, length: 0), marked: nil, in: view))
        let afterHello = try XCTUnwrap(InputSelectionGeometry.geometry(selection: NSRange(location: 5, length: 0), marked: nil, in: view))
        XCTAssertTrue(atStart.selectionRects.isEmpty)
        XCTAssertGreaterThan(try XCTUnwrap(afterHello.caretRect).minX, try XCTUnwrap(atStart.caretRect).minX)
        let selection = try XCTUnwrap(InputSelectionGeometry.geometry(selection: NSRange(location: 0, length: 5), marked: NSRange(location: 1, length: 3), in: view))
        XCTAssertNil(selection.caretRect)
        XCTAssertFalse(selection.selectionRects.isEmpty)
        XCTAssertFalse(selection.markedRects.isEmpty)
        for rect in selection.selectionRects + selection.markedRects { XCTAssertTrue(scroll.contentView.bounds.contains(rect)) }
    }

    func testWrappedAndBidirectionalRangesProduceSeparateVisibleSegments() throws {
        let text = "abc אבגד xyz " + String(repeating: "word ", count: 30)
        let (_, view) = makeView(text, width: 95, height: 110)
        let result = try XCTUnwrap(InputSelectionGeometry.geometry(selection: NSRange(location: 0, length: (text as NSString).length), marked: nil, in: view))
        XCTAssertGreaterThan(result.selectionRects.count, 2)
        XCTAssertGreaterThan(Set(result.selectionRects.map { Int($0.minY) }).count, 1)
        let firstLine = result.selectionRects.filter { abs($0.minY - result.selectionRects[0].minY) < 0.1 }
        XCTAssertGreaterThan(firstLine.count, 1)
        XCTAssertTrue(result.selectionRects.allSatisfy { $0.width > 0 && $0.height > 0 })
    }

    func testSelectedHiddenWrapWhitespaceShowsClippedMarker() throws {
        let text = String(repeating: "abc        def ", count: 20)
        var found = false
        for width in [CGFloat(30), 35, 40, 45, 50, 60, 75, 90] {
            let (scroll, view) = makeView(text, width: width, height: 120)
            guard let line = view.visibleLayout?.lines.first,
                  let placement = line.placements.first(where: { $0.fragment.hiddenLength > 0 }) else { continue }
            let start = line.line.location + placement.fragment.visibleRange.upperBound
            let selected = NSRange(location: start, length: 1)
            let geometry = try XCTUnwrap(InputSelectionGeometry.geometry(selection: selected, marked: selected, in: view))
            guard let marker = geometry.selectionRects.first else { continue }
            XCTAssertEqual(geometry.selectionRects.count, 1)
            XCTAssertEqual(geometry.markedRects, geometry.selectionRects)
            XCTAssertTrue(scroll.contentView.bounds.contains(marker))
            XCTAssertGreaterThan(marker.width, 0)
            let before = NSRange(location: start - 1, length: 1)
            let other = try XCTUnwrap(InputSelectionGeometry.geometry(selection: before, marked: nil, in: view))
            XCTAssertFalse(other.selectionRects.isEmpty)
            XCTAssertTrue(other.selectionRects.allSatisfy { $0.intersection(marker).isNull || $0.intersection(marker).width < 0.01 })
            found = true
            break
        }
        XCTAssertTrue(found, "Expected a visible hidden-whitespace wrap fragment")
    }

    func testHiddenWhitespaceMarkerUsesTerminalRightToLeftRun() throws {
        let text = String(repeating: "abc אבגד        xyz ", count: 20)
        var checked = false
        for width in [CGFloat(45), 50, 55, 60, 65, 70, 80, 90, 100, 110, 120, 130] {
            let (scroll, view) = makeView(text, width: width, height: 140)
            guard let layout = view.visibleLayout else { continue }
            for line in layout.lines {
                for placement in line.placements where placement.fragment.hiddenLength > 0 {
                    let fragment = placement.fragment
                    let end = fragment.visibleRange.upperBound
                    guard let runs = CTLineGetGlyphRuns(fragment.line) as? [CTRun],
                          let run = runs.first(where: {
                              let range = CTRunGetStringRange($0)
                              return range.location < end && end <= range.location + range.length
                          }), CTRunGetStatus(run).contains(.rightToLeft),
                          let bounds = CoreTextRunGeometry.horizontalBounds(of: run),
                          placement.frame.minX + bounds.lowerBound >= 4 else { continue }
                    let selected = NSRange(location: line.line.location + end, length: 1)
                    let result = try XCTUnwrap(InputSelectionGeometry.geometry(selection: selected, marked: nil, in: view))
                    guard let marker = result.selectionRects.first else { continue }
                    XCTAssertEqual(result.selectionRects.count, 1)
                    XCTAssertTrue(scroll.contentView.bounds.contains(marker))
                    XCTAssertEqual(marker.maxX, placement.frame.minX + bounds.lowerBound, accuracy: 0.1)
                    checked = true
                    break
                }
                if checked { break }
            }
            if checked { break }
        }
        XCTAssertTrue(checked, "Expected a visible RTL terminal run with hidden whitespace")
    }

    func testDelimiterAndEmptyLineHaveVisibleSelectionAndCaret() throws {
        let (_, view) = makeView("\nsecond", width: 180, height: 80)
        let selected = try XCTUnwrap(InputSelectionGeometry.geometry(selection: NSRange(location: 0, length: 1), marked: nil, in: view))
        XCTAssertEqual(selected.selectionRects.count, 1)
        XCTAssertEqual(try XCTUnwrap(selected.selectionRects.first).width, 4, accuracy: 0.01)
        let caret = try XCTUnwrap(InputSelectionGeometry.geometry(selection: NSRange(location: 0, length: 0), marked: nil, in: view))
        XCTAssertGreaterThan(try XCTUnwrap(caret.caretRect).height, 0)
    }

    func testClipsPartialViewportAndRejectsInvalidRanges() throws {
        let (scroll, view) = makeView("a😀b\n" + String(repeating: "line\n", count: 40), width: 100, height: 45)
        let layout = try XCTUnwrap(view.visibleLayout)
        let first = try XCTUnwrap(layout.lines.first)
        let y = first.line.yPosition + first.line.data.lineHeight / 2
        scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
        scroll.reflectScrolledClipView(scroll.contentView)
        view.updateViewport()
        let all = try XCTUnwrap(InputSelectionGeometry.geometry(selection: NSRange(location: 0, length: view.content.length), marked: nil, in: view))
        XCTAssertFalse(all.selectionRects.isEmpty)
        XCTAssertTrue(all.selectionRects.allSatisfy { scroll.contentView.bounds.contains($0) })
        XCTAssertNil(InputSelectionGeometry.geometry(selection: NSRange(location: 2, length: 0), marked: nil, in: view))
        XCTAssertNil(InputSelectionGeometry.geometry(selection: NSRange(location: 0, length: Int.max), marked: nil, in: view))
        XCTAssertNil(InputSelectionGeometry.geometry(selection: NSRange(location: 0, length: 0), marked: NSRange(location: 2, length: 0), in: view))
    }

    func testRetiredOrDetachedViewsHaveNoPresentationGeometry() throws {
        let (scroll, view) = makeView("abc", width: 180, height: 80)
        scroll.documentView = nil
        XCTAssertNil(InputSelectionGeometry.geometry(selection: NSRange(location: 0, length: 0), marked: nil, in: view))
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        view.retireInputView()
        XCTAssertNil(InputSelectionGeometry.geometry(selection: NSRange(location: 0, length: 0), marked: nil, in: view))
    }

    private func makeView(_ text: String, width: CGFloat, height: CGFloat) -> (NSScrollView, ReadOnlyDocumentView) {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        let content = NSAttributedString(string: text, attributes: [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)])
        let view = ReadOnlyDocumentView(snapshot: content, fallbackHeight: 16)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        return (scroll, view)
    }
}
#endif
