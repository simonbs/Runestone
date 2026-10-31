#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputDragSelectionTests: XCTestCase {
    func testDraggingAcrossAnchorPreservesDirectionAndStopsAfterExternalChange() throws {
        let revision = UUID()
        var selectionRevision = UUID()
        var drag = PreparedInputDragSelection(anchor: 5, selection: NSRange(location: 5, length: 0),
                                               contentRevision: revision, selectionRevision: selectionRevision)
        let backwards = try XCTUnwrap(drag.selection(to: 2, current: NSRange(location: 5, length: 0), contentRevision: revision, selectionRevision: selectionRevision))
        XCTAssertEqual(backwards, NSRange(location: 2, length: 3))
        selectionRevision = UUID()
        drag.didApply(selectionRevision: selectionRevision)
        let forwards = try XCTUnwrap(drag.selection(to: 9, current: backwards, contentRevision: revision, selectionRevision: selectionRevision))
        XCTAssertEqual(forwards, NSRange(location: 5, length: 4))
        XCTAssertNil(drag.selection(to: 10, current: NSRange(location: 0, length: 0), contentRevision: revision, selectionRevision: selectionRevision))
        XCTAssertNil(drag.selection(to: 10, current: forwards, contentRevision: UUID(), selectionRevision: selectionRevision))
        XCTAssertNil(drag.selection(to: 10, current: forwards, contentRevision: revision, selectionRevision: UUID()))
    }
}
#endif
