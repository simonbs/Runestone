#if os(macOS)
import AppKit
#endif
import CoreGraphics
#if os(iOS)
import UIKit
#endif

enum ScreenScale {
    static var rawValue: CGFloat {
        #if os(iOS)
        return UIScreen.main.scale
        #else
        return NSScreen.main?.backingScaleFactor ?? 1
        #endif
    }
}
