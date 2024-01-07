//#if os(iOS)
//import UIKit
//
//final class UITextRangeAdjustmentGestureTracker<LineManagerType: LineManaging> {
//    typealias State = SelectedRangeReadable
//
//    private let state: State
//    private let viewportScroller: ViewportScroller<LineManagerType>
//    // Store a reference to instances of the private type UITextRangeAdjustmentGestureRecognizer
//    // in order to track adjustments to the selected text range and scroll the text view when
//    // the handles approach the bottom. The approach is based on the one described in
//    // Steve Shephard's blog post "Adventures with UITextInteraction".
//    // https://steveshepard.com/blog/adventures-with-uitextinteraction/
//    private var textRangeAdjustmentGestureRecognizers: Set<UIGestureRecognizer> = []
//    private var previousSelectedRangeDuringGestureHandling: NSRange?
//
//    init(state: State, viewportScroller: ViewportScroller<LineManagerType>) {
//        self.state = state
//        self.viewportScroller = viewportScroller
//    }
//
//    func beginTrackingGestureRecognizerIfNeeded(_ gestureRecognizer: UIGestureRecognizer) {
//        guard let klass = NSClassFromString("UITextRangeAdjustmentGestureRecognizer") else {
//            return
//        }
//        guard !textRangeAdjustmentGestureRecognizers.contains(gestureRecognizer) && gestureRecognizer.isKind(of: klass) else {
//            return
//        }
//        gestureRecognizer.addTarget(self, action: #selector(handleTextRangeAdjustmentPan(_:)))
//        textRangeAdjustmentGestureRecognizers.insert(gestureRecognizer)
//    }
//
//    @objc private func handleTextRangeAdjustmentPan(_ gestureRecognizer: UIPanGestureRecognizer) {
//        // This function scroll the text view when the selected range is adjusted.
//        if gestureRecognizer.state == .began {
//            previousSelectedRangeDuringGestureHandling = state.selectedRange
//        } else if gestureRecognizer.state == .changed, let previousSelectedRange = previousSelectedRangeDuringGestureHandling {
//            if state.selectedRange.lowerBound != previousSelectedRange.lowerBound {
//                // User is adjusting the lower bound (location) of the selected range.
//                let visibleRange = NSRange(location: state.selectedRange.lowerBound, length: 0)
//                viewportScroller.scroll(toVisibleRange: visibleRange)
//            } else if state.selectedRange.upperBound != previousSelectedRange.upperBound {
//                // User is adjusting the upper bound (length) of the selected range.
//                let visibleRange = NSRange(location: state.selectedRange.upperBound, length: 0)
//                viewportScroller.scroll(toVisibleRange: visibleRange)
//            }
//            previousSelectedRangeDuringGestureHandling = state.selectedRange
//        }
//    }
//}
//#endif
