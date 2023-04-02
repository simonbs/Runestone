import Combine
import Foundation

final class GoToLineNavigator {
    private unowned let textView: TextView
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let viewportScroller: ViewportScroller

    init(
        textView: TextView,
        lineManager: CurrentValueSubject<LineManager, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        viewportScroller: ViewportScroller
    ) {
        self.textView = textView
        self.lineManager = lineManager
        self.selectedRange = selectedRange
        self.viewportScroller = viewportScroller
    }

    func goToLine(_ lineIndex: Int, select selection: GoToLineSelection = .beginning) -> Bool {
        guard lineIndex >= 0 && lineIndex < lineManager.value.lineCount else {
            return false
        }
        // I'm not exactly sure why this is necessary but if the text view is the first responder as we jump
        // to the line and we don't resign the first responder first, the caret will disappear after we have
        // jumped to the specified line.
        textView.resignFirstResponder()
        textView.becomeFirstResponder()
        let line = lineManager.value.line(atRow: lineIndex)
        let visibleRange =  NSRange(location: line.location, length: 0)
        viewportScroller.scroll(toVisibleRange: visibleRange)
        textView.layoutIfNeeded()
        switch selection {
        case .beginning:
            selectedRange.value = NSRange(location: line.location, length: 0)
        case .end:
            selectedRange.value = NSRange(location: line.data.length, length: line.data.length)
        case .line:
            selectedRange.value = NSRange(location: line.location, length: line.data.length)
        }
        return true
    }
}
