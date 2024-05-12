import _RunestoneMultiPlatform
import CoreGraphics
import CoreText
import Foundation
#if os(iOS)
import UIKit
#endif

struct TextLineFragmentRenderer<LineType: Line>: LineFragmentRendering {
    func render(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
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
