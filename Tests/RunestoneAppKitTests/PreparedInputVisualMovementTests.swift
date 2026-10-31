#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputVisualMovementTests: XCTestCase {
    func testPreferredXSurvivesShortLineAndEmptyLine() throws {
        let (window, _, view) = makeView("abcdef\nx\n\nabcdef", width: 240, height: 130)
        let first = try XCTUnwrap(PreparedInputVisualMovement.vertical(from: 5, direction: .down,
                                                                      preferredScreenX: nil, in: view))
        XCTAssertEqual(first.location, 8) // The short line's end.
        let second = try XCTUnwrap(PreparedInputVisualMovement.vertical(from: first.location, direction: .down,
                                                                       preferredScreenX: first.preferredScreenX, in: view))
        XCTAssertEqual(second.location, 9) // The empty line.
        let third = try XCTUnwrap(PreparedInputVisualMovement.vertical(from: second.location, direction: .down,
                                                                      preferredScreenX: second.preferredScreenX, in: view))
        XCTAssertEqual(third.location, 15) // Return to the original visual column.
        XCTAssertEqual(first.preferredScreenX, third.preferredScreenX, accuracy: 0.001)
        withExtendedLifetime(window) {}
    }

    func testVisualMovementFollowsWrappedFragmentsBeforeTheNextLogicalLine() throws {
        let (window, _, view) = makeView("alpha beta gamma delta epsilon zeta\nsecond", width: 75, height: 140)
        let line = try XCTUnwrap(view.visibleLayout?.lines.first)
        XCTAssertGreaterThan(line.placements.count, 1)
        let next = try XCTUnwrap(PreparedInputVisualMovement.vertical(from: 0, direction: .down,
                                                                     preferredScreenX: nil, in: view))
        XCTAssertGreaterThan(next.location, 0)
        XCTAssertLessThan(next.location, line.line.data.length)
        XCTAssertTrue(line.placements.dropFirst().contains { $0.documentRange.location <= next.location &&
            next.location <= $0.documentRange.upperBound })
        withExtendedLifetime(window) {}
    }

    func testUnicodeAndBidirectionalTargetsNeverSplitComposedCharacters() throws {
        let text = "ab👩‍💻e\u{301}z\nאב👨‍👩‍👧‍👦גד\nzz👩‍💻end"
        let (window, _, view) = makeView(text, width: 300, height: 120)
        let firstEnd = (text as NSString).range(of: "👩‍💻").upperBound
        let down = try XCTUnwrap(PreparedInputVisualMovement.vertical(from: firstEnd, direction: .down,
                                                                     preferredScreenX: nil, in: view))
        let next = try XCTUnwrap(PreparedInputVisualMovement.vertical(from: down.location, direction: .down,
                                                                     preferredScreenX: down.preferredScreenX, in: view))
        let content = text as NSString
        for offset in [down.location, next.location] where offset > 0 && offset < content.length {
            XCTAssertEqual(content.rangeOfComposedCharacterSequence(at: offset).location, offset)
        }
        withExtendedLifetime(window) {}
    }

    func testVisualLineEdgesAndEmptyLine() throws {
        let (window, _, view) = makeView("abc אבגד xyz\n\nlast", width: 300, height: 100)
        let firstLineLength = ("abc אבגד xyz" as NSString).length
        XCTAssertEqual(PreparedInputVisualMovement.lineEdge(from: 2, edge: .beginning, in: view), 0)
        XCTAssertEqual(PreparedInputVisualMovement.lineEdge(from: 2, edge: .end, in: view), firstLineLength)
        let empty = firstLineLength + 1
        XCTAssertEqual(PreparedInputVisualMovement.lineEdge(from: empty, edge: .beginning, in: view), empty)
        XCTAssertEqual(PreparedInputVisualMovement.lineEdge(from: empty, edge: .end, in: view), empty)
        withExtendedLifetime(window) {}
    }

    func testLogicalAndVisualLineEdgesDifferForRightToLeftText() throws {
        let text = "אבגד"
        let (window, _, view) = makeView(text, width: 240, height: 80)
        let logicalStart = try XCTUnwrap(PreparedInputVisualMovement.logicalLineEdge(from: 1, edge: .beginning, in: view))
        let visualLeft = try XCTUnwrap(PreparedInputVisualMovement.lineEdge(from: 1, edge: .beginning, in: view))
        XCTAssertEqual(logicalStart, 0)
        XCTAssertEqual(visualLeft, (text as NSString).length)
        XCTAssertNotEqual(logicalStart, visualLeft)
        withExtendedLifetime(window) {}
    }

    func testLogicalEdgesUseCurrentWrappedFragment() throws {
        let (window, _, view) = makeView("alpha beta gamma delta epsilon", width: 75, height: 140)
        let line = try XCTUnwrap(view.visibleLayout?.lines.first)
        XCTAssertGreaterThan(line.placements.count, 1)
        let row = line.placements[1]
        let location = line.line.location + row.fragment.range.location
        XCTAssertEqual(PreparedInputVisualMovement.logicalLineEdge(from: location, edge: .beginning, in: view),
                       line.line.location + row.fragment.visibleRange.location)
        XCTAssertEqual(PreparedInputVisualMovement.logicalLineEdge(from: location, edge: .end, in: view),
                       line.line.location + row.fragment.visibleRange.upperBound)
        withExtendedLifetime(window) {}
    }

    func testOffscreenOrDetachedGeometryDoesNotInventADestination() throws {
        let (window, scroll, view) = makeView("one\ntwo\nthree\nfour\nfive", width: 160, height: 17)
        XCTAssertNil(PreparedInputVisualMovement.vertical(from: 0, direction: .up, preferredScreenX: nil, in: view))
        XCTAssertNil(PreparedInputVisualMovement.vertical(from: 0, direction: .down, preferredScreenX: nil, in: view))
        scroll.removeFromSuperview()
        XCTAssertNil(PreparedInputVisualMovement.vertical(from: 0, direction: .down, preferredScreenX: nil, in: view))
        XCTAssertNil(PreparedInputVisualMovement.lineEdge(from: 0, edge: .end, in: view))
        withExtendedLifetime(window) {}
    }

    func testHorizontalMovementUsesVisualOrderInsideBidirectionalRun() throws {
        let text = "ab אבגד cd"
        let (window, _, view) = makeView(text, width: 300, height: 100)
        let secondHebrew = (text as NSString).range(of: "ב").location
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: secondHebrew, direction: .left, in: view),
                       .moved(secondHebrew + 1))
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: secondHebrew + 1, direction: .right, in: view),
                       .moved(secondHebrew))
        // The junction between LTR and RTL has two caret affinities; this
        // selection representation cannot decide which one was intended.
        let junction = (text as NSString).range(of: "א").location
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: junction, direction: .right, in: view), .unavailable)
        withExtendedLifetime(window) {}
    }

    func testHorizontalMovementStepsOverWholeEmojiAndCombiningClusters() throws {
        let text = "ae\u{301}👩‍💻z"
        let (window, _, view) = makeView(text, width: 300, height: 100)
        let combining = (text as NSString).range(of: "e\u{301}")
        let emoji = (text as NSString).range(of: "👩‍💻")
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: combining.location, direction: .right, in: view),
                       .moved(combining.upperBound))
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: emoji.location, direction: .right, in: view),
                       .moved(emoji.upperBound))
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: emoji.upperBound, direction: .left, in: view),
                       .moved(emoji.location))
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: combining.location + 1, direction: .right, in: view),
                       .unavailable)
        withExtendedLifetime(window) {}
    }

    func testHorizontalMovementCrossesVisibleCRLFWithoutSplittingIt() throws {
        let (window, _, view) = makeView("ab\r\ncd", width: 160, height: 100)
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: 2, direction: .right, in: view), .moved(4))
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: 4, direction: .left, in: view), .moved(2))
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: 3, direction: .left, in: view), .unavailable)
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: 0, direction: .left, in: view), .boundary)
        withExtendedLifetime(window) {}
    }

    func testHorizontalMovementRejectsCrossingIntoRightToLeftRow() throws {
        let (window, _, view) = makeView("abc\nאבגד", width: 200, height: 100)
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: 3, direction: .right, in: view), .unavailable)
        withExtendedLifetime(window) {}
    }

    func testLogicalLineEdgeRejectsCaretInsideCRLF() throws {
        let (window, _, view) = makeView("ab\r\ncd", width: 200, height: 100)
        XCTAssertNil(PreparedInputVisualMovement.logicalLineEdge(from: 3, edge: .beginning, in: view))
        XCTAssertNil(PreparedInputVisualMovement.logicalLineEdge(from: 3, edge: .end, in: view))
        XCTAssertEqual(PreparedInputVisualMovement.logicalLineEdge(from: 2, edge: .end, in: view), 2)
        withExtendedLifetime(window) {}
    }

    func testHorizontalMovementRejectsOffscreenNeighbor() throws {
        let (window, _, view) = makeView("one\ntwo\nthree", width: 160, height: 17)
        XCTAssertEqual(PreparedInputVisualMovement.horizontal(from: 3, direction: .right, in: view), .unavailable)
        withExtendedLifetime(window) {}
    }

    private func makeView(_ text: String, width: CGFloat, height: CGFloat) -> (NSWindow, NSScrollView, ReadOnlyDocumentView) {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: text,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)]), fallbackHeight: 16)
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        return (window, scroll, view)
    }
}
#endif
