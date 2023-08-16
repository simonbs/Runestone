#if os(macOS)
import AppKit
typealias MultiPlatformView = NSView
#else
import UIKit
typealias MultiPlatformView = UIView
#endif

#if os(iOS) || os(xrOS)
extension UIView {
    var layerIfLoaded: CALayer? {
        layer
    }
}
#endif

#if os(macOS)
extension NSView {
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

func UIGraphicsGetCurrentContext() -> CGContext? {
    NSGraphicsContext.current?.cgContext
}
#endif
