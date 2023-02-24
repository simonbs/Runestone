#if os(macOS)
import AppKit
public typealias MultiPlatformScrollView = NSScrollView
#else
import UIKit
public typealias MultiPlatformScrollView = UIScrollView
#endif

#if os(macOS)
public extension NSScrollView {
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
