#if os(macOS)
import AppKit
package typealias MultiPlatformScrollView = NSScrollView
#else
import UIKit
package typealias MultiPlatformScrollView = UIScrollView
#endif

#if os(macOS)
package extension NSScrollView {
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
