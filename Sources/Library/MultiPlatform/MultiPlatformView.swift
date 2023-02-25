#if os(macOS)
import AppKit
public typealias MultiPlatformView = NSView
#else
import UIKit
public typealias MultiPlatformView = UIView
#endif

#if os(iOS)
public extension UIView {
    var layerIfLoaded: CALayer? {
        layer
    }
}
#endif

#if os(macOS)
public extension NSView {
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

public func UIGraphicsGetCurrentContext() -> CGContext? {
    NSGraphicsContext.current?.cgContext
}
#endif
