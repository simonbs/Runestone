#if canImport(AppKit)
import AppKit

extension ReadOnlyDocumentView {
    /// Keep layout and backdrop drawing edge-to-edge, but reveal text inside
    /// the area not covered by native title/status accessories.
    func unobscuredContentViewport(_ viewport: NSRect) -> NSRect {
        let scroll = enclosingScrollView
        let insets = scroll?.contentInsets ?? NSEdgeInsetsZero
        let top = max(0, insets.top)
        var bottom = max(0, insets.bottom)
        if let scroll, scroll.scrollerStyle == .legacy, let scroller = scroll.horizontalScroller, !scroller.isHidden {
            let overlap = scroll.contentView.frame.intersection(scroller.frame)
            if !overlap.isNull { bottom += overlap.height }
        }
        return NSRect(x: viewport.minX, y: viewport.minY + top,
                      width: viewport.width, height: max(0, viewport.height - top - bottom))
    }
}
#endif
