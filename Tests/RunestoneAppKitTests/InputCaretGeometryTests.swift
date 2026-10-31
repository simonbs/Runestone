#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneEngine
@testable import RunestoneAppKit
import XCTest

final class InputCaretGeometryTests: XCTestCase {
    private let font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)

    func testCaretUsesDocumentAndFragmentCoordinates() throws {
        let (lineStart, placements) = try makePlacements("hello", width: 200)
        let placement = try XCTUnwrap(placements.first)
        let start = try XCTUnwrap(InputCaretGeometry.rect(for: placement, lineStart: lineStart,
                                                         documentOffset: lineStart, caretWidth: 2))
        let end = try XCTUnwrap(InputCaretGeometry.rect(for: placement, lineStart: lineStart,
                                                       documentOffset: lineStart + 5, caretWidth: 2))
        XCTAssertGreaterThan(lineStart, 0)
        XCTAssertGreaterThan(placement.frame.minY, 0)
        XCTAssertEqual(start.minY, placement.frame.minY + placement.fragment.verticalGeometry.textTop, accuracy: 0.001)
        XCTAssertEqual(start.height, placement.fragment.baseSize.height, accuracy: 0.001)
        XCTAssertEqual(start.width, 2, accuracy: 0.001)
        XCTAssertGreaterThan(end.minX, start.minX)
    }

    func testWrapBoundaryBelongsToEitherExplicitlySelectedPlacement() throws {
        let (lineStart, placements) = try makePlacements(String(repeating: "word ", count: 12), width: 60)
        XCTAssertGreaterThan(placements.count, 1)
        let first = placements[0]
        let second = placements[1]
        let offset = lineStart + first.fragment.range.upperBound
        XCTAssertEqual(offset, lineStart + second.fragment.range.location)
        let upstream = try XCTUnwrap(InputCaretGeometry.rect(for: first, lineStart: lineStart,
                                                            documentOffset: offset, caretWidth: 1))
        let downstream = try XCTUnwrap(InputCaretGeometry.rect(for: second, lineStart: lineStart,
                                                              documentOffset: offset, caretWidth: 1))
        XCTAssertLessThan(upstream.minY, downstream.minY)
        XCTAssertNil(InputCaretGeometry.rect(for: second, lineStart: Int.max, documentOffset: Int.max, caretWidth: 1))
    }

    func testHiddenTailMapsToVisibleEnd() throws {
        let text = String(repeating: "abc        def ", count: 8)
        var match: (Int, LogicalLineLayoutController.Placement)?
        for width in [CGFloat(25), 30, 35, 40, 45, 50, 60, 75, 90] {
            let (lineStart, placements) = try makePlacements(text, width: width)
            if let placement = placements.first(where: { $0.fragment.hiddenLength > 0 }) {
                match = (lineStart, placement)
                break
            }
        }
        let (lineStart, placement) = try XCTUnwrap(match)
        let visibleEnd = lineStart + placement.fragment.visibleRange.upperBound
        let trailing = visibleEnd + placement.fragment.hiddenLength
        let start = try XCTUnwrap(InputCaretGeometry.rect(for: placement, lineStart: lineStart,
                                                         documentOffset: visibleEnd, caretWidth: 1))
        let end = try XCTUnwrap(InputCaretGeometry.rect(for: placement, lineStart: lineStart,
                                                       documentOffset: trailing, caretWidth: 1))
        XCTAssertEqual(start, end)
    }

    func testRightToLeftTextUsesCoreTextPrimaryCaretOffset() throws {
        let (lineStart, placements) = try makePlacements("אבגד", width: 200)
        let placement = try XCTUnwrap(placements.first)
        let start = try XCTUnwrap(InputCaretGeometry.rect(for: placement, lineStart: lineStart,
                                                         documentOffset: lineStart, caretWidth: 1))
        let end = try XCTUnwrap(InputCaretGeometry.rect(for: placement, lineStart: lineStart,
                                                       documentOffset: lineStart + 4, caretWidth: 1))
        XCTAssertGreaterThan(start.minX, end.minX)
    }

    func testRejectsInvalidOffsetsAndGeometryInputs() throws {
        let (lineStart, placements) = try makePlacements("hello", width: 200)
        let placement = try XCTUnwrap(placements.first)
        XCTAssertNil(InputCaretGeometry.rect(for: placement, lineStart: lineStart,
                                            documentOffset: lineStart - 1, caretWidth: 1))
        XCTAssertNil(InputCaretGeometry.rect(for: placement, lineStart: lineStart,
                                            documentOffset: lineStart + 6, caretWidth: 1))
        XCTAssertNil(InputCaretGeometry.rect(for: placement, lineStart: -1, documentOffset: 0, caretWidth: 1))
        XCTAssertNil(InputCaretGeometry.rect(for: placement, lineStart: Int.max, documentOffset: Int.max, caretWidth: 1))
        XCTAssertNil(InputCaretGeometry.rect(for: placement, lineStart: lineStart, documentOffset: Int.max, caretWidth: 1))
        XCTAssertNil(InputCaretGeometry.rect(for: placement, lineStart: lineStart, documentOffset: lineStart, caretWidth: 0))
        XCTAssertNil(InputCaretGeometry.rect(for: placement, lineStart: lineStart, documentOffset: lineStart, caretWidth: .infinity))
        XCTAssertNil(InputCaretGeometry.rect(for: placement, lineStart: lineStart + 1, documentOffset: lineStart + 1, caretWidth: 1))
    }

    private func makePlacements(_ text: String, width: CGFloat) throws -> (Int, [LogicalLineLayoutController.Placement]) {
        let manager = LineManager(stringView: StringView(string: "prefix\n" + text))
        manager.rebuild()
        let line = manager.lastLine
        let lineStart = line.location
        let controller = LogicalLineLayoutController(manager: manager, line: line)
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        XCTAssertTrue(controller.prepare(attributed, width: width, heightMultiplier: 1.5, fallbackHeight: 16))
        return (lineStart, controller.layout(.toLocation(attributed.length)))
    }
}
#endif
