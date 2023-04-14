#if os(macOS)
import AppKit
public typealias MultiPlatformColor = NSColor
#else
import UIKit
public typealias MultiPlatformColor = UIColor
#endif

#if os(macOS)
extension NSColor {
    static var label: NSColor {
        .labelColor
    }

    static var background: NSColor {
        .textBackgroundColor
    }

    static var systemFill: NSColor {
        .systemGray.withAlphaComponent(0.1)
    }
}
#endif
