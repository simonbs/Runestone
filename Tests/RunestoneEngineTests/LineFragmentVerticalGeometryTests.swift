import RunestoneEngine
import XCTest

final class LineFragmentVerticalGeometryTests: XCTestCase {
    func testTextAndCaretStayCenteredAtDifferentLineHeights() {
        assertPlacement(height: 20, top: 0, baseline: 16)
        assertPlacement(height: 30, top: 5, baseline: 21)
        assertPlacement(height: 10, top: -5, baseline: 11)
    }

    private func assertPlacement(height: CGFloat, top: CGFloat, baseline: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        let geometry = LineFragmentVerticalGeometry(baseHeight: 20, scaledHeight: height, descent: 4)
        XCTAssertEqual(geometry.textTop, top, file: file, line: line)
        XCTAssertEqual(geometry.topDownBaseline, baseline, file: file, line: line)
        XCTAssertEqual(geometry.coreTextBaseline, height - baseline, file: file, line: line)
    }
}
