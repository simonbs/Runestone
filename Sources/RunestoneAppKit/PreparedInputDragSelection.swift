#if canImport(AppKit)
import Foundation

/// Tracks the fixed end of one pointer gesture without retaining its event.
/// A changed snapshot or an unrelated selection ends the gesture.
struct PreparedInputDragSelection {
    let anchor: Int
    let contentRevision: UUID
    let clickCount: Int
    private let initialUnit: NSRange
    private(set) var expectedSelection: NSRange
    private(set) var selectionRevision: UUID

    init(anchor: Int, selection: NSRange, contentRevision: UUID, selectionRevision: UUID, clickCount: Int = 1) {
        self.anchor = anchor
        self.clickCount = clickCount
        self.initialUnit = selection
        self.expectedSelection = selection
        self.contentRevision = contentRevision
        self.selectionRevision = selectionRevision
    }

    mutating func selection(to target: Int, unit: NSRange? = nil, current: NSRange,
                            contentRevision: UUID, selectionRevision: UUID) -> NSRange? {
        guard anchor >= 0, target >= 0, current == expectedSelection,
              contentRevision == self.contentRevision, selectionRevision == self.selectionRevision else { return nil }
        let result: NSRange
        if clickCount > 1 {
            result = NSUnionRange(initialUnit, unit ?? NSRange(location: target, length: 0))
        } else {
            let lower = min(anchor, target)
            let upper = max(anchor, target)
            result = NSRange(location: lower, length: upper - lower)
        }
        expectedSelection = result
        return result
    }

    mutating func didApply(selectionRevision: UUID) { self.selectionRevision = selectionRevision }
}
#endif
