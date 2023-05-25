import Combine
import CoreGraphics
import CoreText
import Foundation
#if os(iOS)
import UIKit
#endif

final class MarkedRangeLineFragmentRenderer: LineFragmentRenderer {
    private let lineFragment: LineFragment
    private let markedRange: NSRange?
    private let backgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
    private let backgroundCornerRadius: CurrentValueSubject<CGFloat, Never>

    init(
        lineFragment: LineFragment,
        markedRange: NSRange?,
        backgroundColor: CurrentValueSubject<MultiPlatformColor, Never>,
        backgroundCornerRadius: CurrentValueSubject<CGFloat, Never>
    ) {
        self.lineFragment = lineFragment
        self.markedRange = markedRange
        self.backgroundColor = backgroundColor
        self.backgroundCornerRadius = backgroundCornerRadius
    }

    func render() {
        guard let markedRange = markedRange else {
            return
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.saveGState()
        let startX = CTLineGetOffsetForStringIndex(lineFragment.line, markedRange.lowerBound, nil)
        let endX = CTLineGetOffsetForStringIndex(lineFragment.line, markedRange.upperBound, nil)
        let rect = CGRect(x: startX, y: 0, width: endX - startX, height: lineFragment.scaledSize.height)
        context.setFillColor(backgroundColor.value.cgColor)
        if backgroundCornerRadius.value > 0 {
            let cornerRadius = backgroundCornerRadius.value
            let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.addPath(path)
            context.fillPath()
        } else {
            context.fill(rect)
        }
        context.restoreGState()
    }
}
