import CoreGraphics
import Foundation

struct LineFragmentSelectionRect {
    let rect: CGRect
    let range: NSRange

    init(rect: CGRect, range: NSRange) {
        self.rect = rect
        self.range = range
    }
}
