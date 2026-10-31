#if canImport(AppKit)
import Foundation

/// Tracks the fixed end of one pointer gesture without retaining its event.
/// A changed snapshot or an unrelated selection ends the gesture.
struct PreparedInputDragSelection {
    let anchor: Int
    let contentRevision: UUID
    private(set) var expectedSelection: NSRange
    private(set) var selectionRevision: UUID

    init(anchor: Int, selection: NSRange, contentRevision: UUID, selectionRevision: UUID) {
        self.anchor = anchor
        self.expectedSelection = selection
        self.contentRevision = contentRevision
        self.selectionRevision = selectionRevision
    }

    mutating func selection(to target: Int, current: NSRange, contentRevision: UUID, selectionRevision: UUID) -> NSRange? {
        guard anchor >= 0, target >= 0, current == expectedSelection,
              contentRevision == self.contentRevision, selectionRevision == self.selectionRevision else { return nil }
        let lower = min(anchor, target)
        let upper = max(anchor, target)
        let result = NSRange(location: lower, length: upper - lower)
        expectedSelection = result
        return result
    }

    mutating func didApply(selectionRevision: UUID) { self.selectionRevision = selectionRevision }
}
#endif
