#if os(macOS)
import AppKit

extension MultiPlatformScrollView {
    var contentSize: CGSize {
        get {
            documentView?.frame.size ?? .zero
        }
        set {
            documentView?.frame.size = newValue
        }
    }

    var contentOffset: CGPoint {
        get {
            documentVisibleRect.origin
        }
        set {
            documentView?.scroll(newValue)
        }
    }

    var contentInset: NSEdgeInsets {
        .zero
    }

    var adjustedContentInset: NSEdgeInsets {
        .zero
    }

    var minimumContentOffset: CGPoint {
        CGPoint(x: adjustedContentInset.left * -1, y: adjustedContentInset.top * -1)
    }

    var maximumContentOffset: CGPoint {
        let maxX = max(contentSize.width - bounds.width, 0)
        let maxY = max(contentSize.height - bounds.height, 0)
        return CGPoint(x: maxX, y: maxY)
    }

    var isDragging: Bool {
        false
    }

    var isDecelerating: Bool {
        false
    }
}
#endif
