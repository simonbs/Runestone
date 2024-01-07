//import Combine
//import Foundation
//
//struct GoToLineNavigator<LineManagerType: LineManaging> {
//    typealias State = SelectedRangeWritable
//
//    let state: State
//    let lineManager: LineManagerType
//    let viewportScroller: ViewportScroller<LineManagerType>
//
//    func goToLine(_ lineIndex: Int, select selection: GoToLineSelection = .beginning) -> Bool {
//        guard lineIndex >= 0 && lineIndex < lineManager.lineCount else {
//            return false
//        }
//        // I'm not exactly sure why this is necessary but if the text view is the first responder as we jump
//        // to the line and we don't resign the first responder first, the caret will disappear after we have
//        // jumped to the specified line.
////        proxyView.view?.resignFirstResponder()
////        proxyView.view?.becomeFirstResponder()
//        let line = lineManager[lineIndex]
//        let visibleRange =  NSRange(location: line.location, length: 0)
//        viewportScroller.scroll(toVisibleRange: visibleRange)
////        proxyView.view?.layoutIfNeeded()
//        switch selection {
//        case .beginning:
//            state.selectedRange = NSRange(location: line.location, length: 0)
//        case .end:
//            state.selectedRange = NSRange(location: line.length, length: line.length)
//        case .line:
//            state.selectedRange = NSRange(location: line.location, length: line.length)
//        }
//        return true
//    }
//}
