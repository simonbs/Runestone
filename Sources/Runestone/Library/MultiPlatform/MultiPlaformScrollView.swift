#if os(macOS)
import AppKit
typealias MultiPlatformScrollView = NSScrollView
#else
import UIKit
typealias MultiPlatformScrollView = UIScrollView
#endif

#if os(macOS)
extension NSScrollView {
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

    var isDragging: Bool {
        false
    }

    var isDecelerating: Bool {
        false
    }
}
#endif
