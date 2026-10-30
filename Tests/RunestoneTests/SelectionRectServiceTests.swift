@testable import Runestone
import UIKit
import XCTest

final class SelectionRectServiceTests: XCTestCase {
    func testSingleLineSelectionMapsNeutralGeometryToUIKitRect() throws {
        let textInputView = TextInputView(theme: DefaultTheme())
        textInputView.scrollViewWidth = 320
        textInputView.textContainerInset = UIEdgeInsets(top: 11, left: 13, bottom: 7, right: 17)
        textInputView.string = "selected text"
        textInputView.layoutLines(toLocation: textInputView.string.length)

        let rects = textInputView.selectionRects(for: IndexedRange(location: 0, length: 8))
        let rect = try XCTUnwrap(rects.first)

        XCTAssertEqual(rects.count, 1)
        XCTAssertEqual(rect.rect.minX, 13, accuracy: 0.5)
        XCTAssertEqual(rect.rect.minY, 11, accuracy: 0.5)
        XCTAssertGreaterThan(rect.rect.width, 0)
        XCTAssertTrue(rect.containsStart)
        XCTAssertTrue(rect.containsEnd)
        XCTAssertFalse(rect.isVertical)
    }

    func testMultilineSelectionPreservesBoundaryFlags() throws {
        let textInputView = TextInputView(theme: DefaultTheme())
        textInputView.scrollViewWidth = 320
        textInputView.string = "first\nsecond"
        textInputView.layoutLines(toLocation: textInputView.string.length)

        let rects = textInputView.selectionRects(for: IndexedRange(location: 2, length: 8))

        XCTAssertEqual(rects.count, 3)
        XCTAssertTrue(try XCTUnwrap(rects.first).containsStart)
        XCTAssertFalse(try XCTUnwrap(rects.first).containsEnd)
        XCTAssertFalse(try XCTUnwrap(rects.last).containsStart)
        XCTAssertTrue(try XCTUnwrap(rects.last).containsEnd)
    }
}
