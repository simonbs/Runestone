import Foundation

extension TextViewController {
    public func goToLine(_ lineIndex: Int, select selection: GoToLineSelection = .beginning) -> Bool {
        guard lineIndex >= 0 && lineIndex < lineManager.lineCount else {
            return false
        }
        // I'm not exactly sure why this is necessary but if the text view is the first responder as we jump
        // to the line and we don't resign the first responder first, the caret will disappear after we have
        // jumped to the specified line.
        textView.resignFirstResponder()
        textView.becomeFirstResponder()
        let line = lineManager.line(atRow: lineIndex)
        layoutManager.layoutLines(toLocation: line.location)
        scrollLocationToVisible(line.location)
        textView.layoutIfNeeded()
        switch selection {
        case .beginning:
            selectedRange = NSRange(location: line.location, length: 0)
        case .end:
            selectedRange = NSRange(location: line.data.length, length: line.data.length)
        case .line:
            selectedRange = NSRange(location: line.location, length: line.data.length)
        }
        return true
    }
}
