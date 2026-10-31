#if canImport(AppKit)
import AppKit
import CoreText

/// Computes caret geometry for a current, nonempty laid-out fragment.
/// The caller selects the fragment at a wrapping boundary and validates that the
/// location is an appropriate insertion boundary. Core Text's primary offset is
/// used; this helper does not resolve bidirectional caret affinity.
///
/// Results are in top-down document coordinates. Empty lines, screen conversion,
/// selection, hit-testing, and stale placement detection are the host's concern.
enum InputCaretGeometry {
    static func rect(for placement: LogicalLineLayoutController.Placement, lineStart: Int,
                     documentOffset: Int, caretWidth: CGFloat) -> CGRect? {
        let fragment = placement.fragment
        let visible = fragment.visibleRange
        guard lineStart >= 0, documentOffset >= lineStart,
              visible.location >= 0, visible.length >= 0, fragment.hiddenLength >= 0,
              visible.location <= Int.max - visible.length else { return nil }
        let visibleEnd = visible.location + visible.length
        guard fragment.hiddenLength <= Int.max - visibleEnd,
              lineStart <= Int.max - visible.location,
              placement.documentRange.location == lineStart + visible.location,
              placement.documentRange.length == visible.length else { return nil }
        let end = visibleEnd + fragment.hiddenLength
        guard lineStart <= Int.max - end else { return nil }
        let localOffset = documentOffset - lineStart
        guard localOffset >= visible.location, localOffset <= end,
              caretWidth.isFinite, caretWidth > 0,
              placement.frame.minX.isFinite, placement.frame.minY.isFinite,
              fragment.baseSize.height.isFinite, fragment.baseSize.height > 0,
              fragment.verticalGeometry.textTop.isFinite else { return nil }

        // The hidden tail occupies character positions but no horizontal space.
        // The trailing insertion point is inclusive and shares the same x.
        let caretOffset = min(localOffset, visibleEnd)
        let x = placement.frame.minX + CTLineGetOffsetForStringIndex(fragment.line, caretOffset, nil)
        let y = placement.frame.minY + fragment.verticalGeometry.textTop
        guard x.isFinite, y.isFinite else { return nil }
        return CGRect(x: x, y: y, width: caretWidth, height: fragment.baseSize.height)
    }
}
#endif
