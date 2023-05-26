#if os(macOS)
import AppKit
public typealias MultiPlatformColor = NSColor
#else
import UIKit
public typealias MultiPlatformColor = UIColor
#endif

#if os(iOS)
extension UIColor {
    static var textBackgroundColor: UIColor {
        .white
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
extension NSColor {
    static var label: NSColor {
        .labelColor
    }

    static var systemFill: NSColor {
        .systemGray.withAlphaComponent(0.1)
    }
}
#endif

extension MultiPlatformColor {
    convenience init(themeColorNamed name: String) {
        let fullName = "theme_" + name
        #if os(iOS)
        self.init(named: fullName, in: .module, compatibleWith: nil)!
        #else
        self.init(named: fullName, bundle: .module)!
        #endif
    }
}
