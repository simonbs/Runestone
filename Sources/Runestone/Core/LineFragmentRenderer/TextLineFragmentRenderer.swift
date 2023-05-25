import CoreGraphics
import CoreText
import Foundation
#if os(iOS)
import UIKit
#endif

final class TextLineFragmentRenderer: LineFragmentRenderer {
    private let lineFragment: LineFragment

    init(lineFragment: LineFragment) {
        self.lineFragment = lineFragment
    }

    func render() {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: lineFragment.scaledSize.height)
        context.scaleBy(x: 1, y: -1)
        let yPosition = lineFragment.descent + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
        context.textPosition = CGPoint(x: 0, y: yPosition)
        CTLineDraw(lineFragment.line, context)
        context.restoreGState()
    }
}
