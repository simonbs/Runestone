#if os(macOS)
import AppKit
public typealias MultiPlatformColor = NSColor
#else
import UIKit
public typealias MultiPlatformColor = UIColor
#endif

#if os(iOS)
package extension UIColor {
    static var textBackgroundColor: UIColor {
        .systemBackground
    }

    static var insertionPointPlaceholderBackgroundColor: UIColor {
        UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(white: 1, alpha: 0.3)
            case .light, .unspecified:
                fallthrough
            @unknown default:
                return UIColor(white: 0, alpha: 0.3)
            }
        }
    }
}
#endif

#if os(macOS)
package extension NSColor {
    static var label: NSColor {
        .labelColor
    }

    static var systemFill: NSColor {
        .systemGray.withAlphaComponent(0.1)
    }
}
#endif
