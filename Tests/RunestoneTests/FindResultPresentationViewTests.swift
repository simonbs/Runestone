@testable import Runestone
import UIKit
import XCTest

final class FindResultPresentationViewTests: XCTestCase {
    func testSelectedResultUsesExpandedRoundedPlateWithShapeShadow() throws {
        let sourceView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        sourceView.text = "match"
        let presentationView = FindResultPresentationView(sourceView: sourceView)
        presentationView.isActive = true
        let sourceRect = CGRect(x: 20, y: 30, width: 42, height: 20)
        let range = HighlightedRange(range: NSRange(location: 0, length: 5),
                                     color: .yellow,
                                     cornerRadius: 5,
                                     presentationRole: .selectedSearchResult)

        presentationView.update(highlightedRanges: [range]) { _ in
            [TextSelectionRect(rect: sourceRect, writingDirection: .natural,
                               containsStart: true, containsEnd: true)]
        }

        XCTAssertEqual(presentationView.selectedResultPlateView.frame,
                       sourceRect.insetBy(dx: -4, dy: -3))
        let plate = try XCTUnwrap(presentationView.selectedResultPlateView.subviews.first)
        XCTAssertEqual(plate.backgroundColor, .yellow)
        XCTAssertEqual(plate.layer.cornerRadius, 5)
        XCTAssertEqual(plate.layer.shadowOpacity, 0.22)
        XCTAssertNotNil(plate.layer.shadowPath)
    }

    func testScrollLayoutAndSelectionChangesReuseCachedGeometryForManyResults() {
        let resultCount = 500
        let sourceView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 2_000))
        sourceView.text = String(repeating: "x", count: resultCount)
        let presentationView = FindResultPresentationView(sourceView: sourceView)
        presentationView.isActive = true
        var geometryCallCount = 0
        let selectionRects: (UITextRange) -> [UITextSelectionRect] = { _ in
            geometryCallCount += 1
            return [TextSelectionRect(rect: CGRect(x: 10, y: 10, width: 8, height: 18),
                                      writingDirection: .natural, containsStart: true, containsEnd: true)]
        }

        presentationView.update(highlightedRanges: ranges(count: resultCount, selectedIndex: 0),
                                selectionRects: selectionRects)
        XCTAssertEqual(geometryCallCount, resultCount)

        for _ in 0 ..< 100 {
            presentationView.updateLayoutIfNeeded(highlightedRanges: ranges(count: resultCount, selectedIndex: 0),
                                                  selectionRects: selectionRects)
        }
        presentationView.update(highlightedRanges: ranges(count: resultCount, selectedIndex: 1),
                                selectionRects: selectionRects)
        XCTAssertEqual(geometryCallCount, resultCount,
                       "Scrolling and moving between existing results must reuse cached text geometry")
    }

    func testChangingSelectionAnimatesThePlateItself() {
        let sourceView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        sourceView.text = "xx"
        let presentationView = FindResultPresentationView(sourceView: sourceView)
        presentationView.isActive = true
        let selectionRects: (UITextRange) -> [UITextSelectionRect] = { range in
            let x = range.start == sourceView.beginningOfDocument ? 10.0 : 30.0
            return [TextSelectionRect(rect: CGRect(x: x, y: 10, width: 10, height: 18),
                                      writingDirection: .natural, containsStart: true, containsEnd: true)]
        }

        presentationView.update(highlightedRanges: ranges(count: 2, selectedIndex: 0),
                                selectionRects: selectionRects)
        presentationView.update(highlightedRanges: ranges(count: 2, selectedIndex: 1),
                                selectionRects: selectionRects)

        XCTAssertNotNil(presentationView.selectedResultPlateView.layer.animation(
            forKey: FindResultPresentationView.bounceAnimationKey
        ))
        XCTAssertEqual(presentationView.selectedResultPlateView.transform, .identity)
    }

    func testFollowUpLayoutDoesNotCancelSelectionAnimation() {
        let sourceView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        sourceView.text = "xx"
        let presentationView = FindResultPresentationView(sourceView: sourceView)
        presentationView.isActive = true
        let selectionRects: (UITextRange) -> [UITextSelectionRect] = { _ in
            [TextSelectionRect(rect: CGRect(x: 10, y: 10, width: 10, height: 18),
                               writingDirection: .natural, containsStart: true, containsEnd: true)]
        }
        presentationView.update(highlightedRanges: ranges(count: 2, selectedIndex: 0),
                                selectionRects: selectionRects)
        presentationView.update(highlightedRanges: ranges(count: 2, selectedIndex: 1),
                                selectionRects: selectionRects)
        XCTAssertNotNil(presentationView.selectedResultPlateView.layer.animation(
            forKey: FindResultPresentationView.bounceAnimationKey
        ))

        sourceView.bounds.origin.y = 20
        presentationView.updateLayoutIfNeeded(highlightedRanges: ranges(count: 2, selectedIndex: 1),
                                              selectionRects: selectionRects)

        XCTAssertNotNil(presentationView.selectedResultPlateView.layer.animation(
            forKey: FindResultPresentationView.bounceAnimationKey
        ))
    }

    private func ranges(count: Int, selectedIndex: Int) -> [HighlightedRange] {
        (0 ..< count).map { index in
            HighlightedRange(id: "result-\(index)",
                             range: NSRange(location: index, length: 1),
                             color: index == selectedIndex ? .yellow : .white,
                             cornerRadius: 3,
                             presentationRole: index == selectedIndex ? .selectedSearchResult : .foundSearchResult)
        }
    }
}
