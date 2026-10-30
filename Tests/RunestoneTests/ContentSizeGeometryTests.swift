@testable import Runestone
import XCTest

final class ContentSizeGeometryTests: XCTestCase {
    private let safeArea = TextInsets(top: 10, left: 13, bottom: 20, right: 7)
    private let textInsets = TextInsets(top: 1.2, left: 2.3, bottom: 3.4, right: 4.5)

    func testWrappedWidthUsesViewportLessHorizontalSafeArea() {
        XCTAssertEqual(ContentSizeGeometry.width(scrollViewWidth: 100.5, safeAreaInset: safeArea,
                                                 textContainerInset: textInsets, mode: .wrapped), 80.5)
    }

    func testUnwrappedWidthIncludesLineGutterInsetsAndSymbolAndRoundsUp() {
        let mode = ContentSizeGeometry.WidthMode.unwrapped(longestLineWidth: 120.1, gutterWidth: 8.2,
                                                           lineBreakSymbolWidth: 1.3)
        XCTAssertEqual(ContentSizeGeometry.width(scrollViewWidth: 100, safeAreaInset: safeArea,
                                                 textContainerInset: textInsets, mode: mode), 137)
    }

    func testUnwrappedWidthUsesViewportMinimumForShortLinesAndViewportFallbackForUnknownWidth() {
        let short = ContentSizeGeometry.WidthMode.unwrapped(longestLineWidth: 10, gutterWidth: 8,
                                                            lineBreakSymbolWidth: 1)
        let unknown = ContentSizeGeometry.WidthMode.unwrapped(longestLineWidth: nil, gutterWidth: 8,
                                                              lineBreakSymbolWidth: 1)
        XCTAssertEqual(ContentSizeGeometry.width(scrollViewWidth: 100, safeAreaInset: safeArea,
                                                 textContainerInset: textInsets, mode: short), 80)
        XCTAssertEqual(ContentSizeGeometry.width(scrollViewWidth: 100, safeAreaInset: safeArea,
                                                 textContainerInset: textInsets, mode: unknown), 116)
    }

    func testHeightIncludesVerticalTextInsetsAndRoundsUp() {
        XCTAssertEqual(ContentSizeGeometry.height(totalLinesHeight: 20.1, textContainerInset: textInsets), 25)
    }
}
