import _RunestoneMultiPlatform
import Combine
import CoreText
import Foundation

struct FirstRectFactory<LineManagerType: LineManaging> {
    let lineManager: LineManagerType
    let viewport: CurrentValueSubject<CGRect, Never>
    let gutterWidthService: GutterWidthService<LineManagerType>
    let estimatedLineHeight: EstimatedLineHeight
    let textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>

    func firstRect(for range: NSRange) -> CGRect {
//        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
//        }
//        let lineLocalLocation = range.location - line.location
//        let lineLocalLength = min(range.length, line.totalLength)
//        let lineLocalRange = NSRange(location: lineLocalLocation, length: lineLocalLength)
//        let lineContentsRect = firstRect(for: lineLocalRange, in: line.lineFragments)
//        let visibleWidth = viewport.value.width - gutterWidthService.gutterWidth
//        let xPosition = lineContentsRect.minX + textContainerInset.value.left + gutterWidthService.gutterWidth
//        let yPosition = line.yPosition + lineContentsRect.minY + textContainerInset.value.top
//        let width = min(lineContentsRect.width, visibleWidth)
//        return CGRect(x: xPosition, y: yPosition, width: width, height: lineContentsRect.height)
    }
}

private extension FirstRectFactory {
    private func firstRect(for lineLocalRange: NSRange, in lineFragments: [any LineFragment]) -> CGRect {
        for lineFragment in lineFragments {
            guard let insertionPointRange = lineFragment.insertionPointRange(forLineLocalRange: lineLocalRange) else {
                continue
            }
            let finalIndex = min(lineFragment.visibleRange.upperBound, insertionPointRange.upperBound)
            let xStart = CTLineGetOffsetForStringIndex(lineFragment.line, insertionPointRange.location, nil)
            let xEnd = CTLineGetOffsetForStringIndex(lineFragment.line, finalIndex, nil)
            let yPosition = lineFragment.yPosition + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
            return CGRect(x: xStart, y: yPosition, width: xEnd - xStart, height: lineFragment.baseSize.height)
        }
        return CGRect(x: 0, y: 0, width: 0, height: estimatedLineHeight.scaledValue.value)
    }
}
