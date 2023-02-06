#if os(macOS)
import AppKit
public typealias MultiPlatformFont = NSFont
public typealias MultiPlatformFontDescriptor = NSFontDescriptor
#else
import UIKit
public typealias MultiPlatformFont = UIFont
public typealias MultiPlatformFontDescriptor = UIFontDescriptor
#endif

extension MultiPlatformFont {
    var totalLineHeight: CGFloat {
        ascender + abs(descender) + leading
    }
}

#if os(macOS)
extension NSFont {
    var lineHeight: CGFloat {
        ceil(ascender + abs(descender) + leading)
    }
}
#endif
