#if os(macOS)
import AppKit
public typealias MultiPlatformColor = NSColor
#else
import UIKit
public typealias MultiPlatformColor = UIColor
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
