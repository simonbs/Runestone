#if os(macOS)
import AppKit
#endif
import CoreGraphics
#if os(iOS)
import UIKit
#endif

extension CGContext {
    func setupToDraw(_ lineFragment: LineFragment) {
        let verticalCenteringOffset = (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
        textMatrix = .identity
        textPosition = CGPoint(x: 0, y: lineFragment.descent + verticalCenteringOffset)
        translateBy(x: 0, y: lineFragment.scaledSize.height)
        scaleBy(x: 1, y: -1)
    }

    func asCurrent(_ block: () -> Void) {
        #if os(iOS)
        UIGraphicsPushContext(self)
        block()
        UIGraphicsPopContext()
        #else
        let oldContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: self, flipped: false)
        block()
        NSGraphicsContext.current = oldContext
        #endif
    }
}
