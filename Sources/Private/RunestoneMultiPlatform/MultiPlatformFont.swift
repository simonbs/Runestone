#if os(macOS)
import AppKit
public typealias MultiPlatformFont = NSFont
package typealias MultiPlatformFontDescriptor = NSFontDescriptor
#else
import UIKit
public typealias MultiPlatformFont = UIFont
package typealias MultiPlatformFontDescriptor = UIFontDescriptor
#endif

package extension MultiPlatformFont {
    var actualLineHeight: CGFloat {
        ascender + abs(descender) + leading
    }
}
