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
        var selectedY: CGFloat = 10
        let selectionRects: (UITextRange) -> [UITextSelectionRect] = { _ in
            geometryCallCount += 1
            return [TextSelectionRect(rect: CGRect(x: 10, y: selectedY, width: 8, height: 18),
                                      writingDirection: .natural, containsStart: true, containsEnd: true)]
        }

        presentationView.update(highlightedRanges: ranges(count: resultCount, selectedIndex: 0),
                                selectionRects: selectionRects)
        XCTAssertEqual(geometryCallCount, resultCount)

        for index in 0 ..< 100 {
            selectedY = 10 + CGFloat(index)
            sourceView.bounds.origin.y = CGFloat(index)
            sourceView.bounds.size.height = 2_000 + CGFloat(index)
            presentationView.updateLayoutIfNeeded(selectionRects: selectionRects)
        }
        XCTAssertEqual(presentationView.selectedResultPlateView.frame.minY, selectedY - 3)
        presentationView.update(highlightedRanges: ranges(count: resultCount, selectedIndex: 1),
                                selectionRects: selectionRects)
        XCTAssertEqual(geometryCallCount, resultCount + 100,
                       "Layout must refresh only the selected result, not every match")
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
        presentationView.updateLayoutIfNeeded(selectionRects: selectionRects)

        XCTAssertNotNil(presentationView.selectedResultPlateView.layer.animation(
            forKey: FindResultPresentationView.bounceAnimationKey
        ))
    }

    func testDimmingCoversViewportOutsideContentAndTracksInsetChanges() throws {
        let sourceView = TextInputView(theme: DefaultTheme())
        sourceView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        sourceView.string = "x"
        sourceView.viewport = CGRect(x: -20, y: -100, width: 360, height: 700)
        let presentationView = FindResultPresentationView(sourceView: sourceView)
        sourceView.addSubview(presentationView)
        presentationView.isActive = true
        let resultRect = CGRect(x: 10, y: 10, width: 10, height: 18)
        let selectionRects: (UITextRange) -> [UITextSelectionRect] = { _ in
            [TextSelectionRect(rect: resultRect, writingDirection: .natural,
                               containsStart: true, containsEnd: true)]
        }
        presentationView.update(highlightedRanges: ranges(count: 1, selectedIndex: 0),
                                selectionRects: selectionRects)
        let dimmingLayer = try XCTUnwrap(presentationView.layer.sublayers?.first as? CAShapeLayer)
        func isDimmed(_ point: CGPoint) throws -> Bool {
            let path = try XCTUnwrap(dimmingLayer.path)
            let localPoint = CGPoint(x: point.x - dimmingLayer.frame.minX,
                                     y: point.y - dimmingLayer.frame.minY)
            return path.contains(localPoint, using: .evenOdd)
        }
        XCTAssertTrue(try isDimmed(CGPoint(x: 100, y: -80)), "Cover the navigation inset")
        XCTAssertTrue(try isDimmed(CGPoint(x: -10, y: 100)), "Cover horizontal insets")
        XCTAssertTrue(try isDimmed(CGPoint(x: 100, y: 580)), "Cover below short content")
        XCTAssertFalse(try isDimmed(CGPoint(x: 15, y: 15)), "Keep result cutouts aligned")

        sourceView.viewport = CGRect(x: 0, y: -160, width: 320, height: 640)
        presentationView.updateLayoutIfNeeded(selectionRects: selectionRects)
        XCTAssertTrue(try isDimmed(CGPoint(x: 100, y: -140)), "Track viewport-only changes")
        XCTAssertFalse(try isDimmed(CGPoint(x: 15, y: 15)))

        presentationView.update(highlightedRanges: [], selectionRects: selectionRects)
        sourceView.viewport = CGRect(x: 0, y: -200, width: 320, height: 680)
        presentationView.updateLayoutIfNeeded(selectionRects: selectionRects)
        XCTAssertTrue(try isDimmed(CGPoint(x: 100, y: -180)), "Dim even without matches")
        XCTAssertTrue(try isDimmed(CGPoint(x: 15, y: 15)))
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
