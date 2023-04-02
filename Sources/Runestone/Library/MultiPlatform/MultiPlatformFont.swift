#if os(macOS)
import AppKit
public typealias MultiPlatformFont = NSFont
typealias MultiPlatformFontDescriptor = NSFontDescriptor
#else
import UIKit
public typealias MultiPlatformFont = UIFont
typealias MultiPlatformFontDescriptor = UIFontDescriptor
#endif

extension MultiPlatformFont {
    var actualLineHeight: CGFloat {
        ascender + abs(descender) + leading
    }
}
