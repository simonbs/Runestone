import CoreGraphics
import Foundation

struct LineFragmentSelectionRect {
    let rect: CGRect
    let range: NSRange
    let extendsBeyondEnd: Bool

    init(rect: CGRect, range: NSRange, extendsBeyondEnd: Bool) {
        self.rect = rect
        self.range = range
        self.extendsBeyondEnd = extendsBeyondEnd
    }
}
