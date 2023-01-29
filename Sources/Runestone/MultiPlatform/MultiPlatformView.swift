#if os(macOS)
import AppKit
public typealias MultiPlatformView = NSView
#else
import UIKit
public typealias MultiPlatformView = UIView
#endif

#if os(macOS)
extension NSView {
    var backgroundColor: NSColor? {
        get {
            if let backgroundColor = layer?.backgroundColor {
                return NSColor(cgColor: backgroundColor)
            } else {
                return nil
            }
        }
        set {
            if backgroundColor != nil {
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

    func layoutIfNeeded() {
        layoutSubtreeIfNeeded()
    }
}

func UIGraphicsGetCurrentContext() -> CGContext? {
    NSGraphicsContext.current?.cgContext
}
#endif
