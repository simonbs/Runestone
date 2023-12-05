#if os(macOS)
import AppKit
package typealias MultiPlatformView = NSView
#else
import UIKit
package typealias MultiPlatformView = UIView
#endif

#if os(iOS)
package extension UIView {
    var layerIfLoaded: CALayer? {
        layer
    }
}
#endif

#if os(macOS)
package extension NSView {
    var layerIfLoaded: CALayer? {
        layer
    }

    var backgroundColor: NSColor? {
        get {
            if let backgroundColor = layer?.backgroundColor {
                return NSColor(cgColor: backgroundColor)
            } else {
                return nil
            }
        }
        set {
            if newValue != nil {
                wantsLayer = true
            }
            layer?.backgroundColor = newValue?.cgColor
        }
    }

    func setNeedsDisplay() {
        setNeedsDisplay(bounds)
    }

    func setNeedsLayout() {
        needsLayout = true
    }

    func layoutIfNeeded() {}
}

package func UIGraphicsGetCurrentContext() -> CGContext? {
    NSGraphicsContext.current?.cgContext
}
#endif
