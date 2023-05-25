import Combine
import CoreText
import Foundation

struct FirstRectFactory {
    let lineManager: CurrentValueSubject<LineManager, Never>
    let lineControllerStorage: LineControllerStorage
    let viewport: CurrentValueSubject<CGRect, Never>
    let gutterWidthService: GutterWidthService
    let estimatedLineHeight: EstimatedLineHeight
    let textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>

    func firstRect(for range: NSRange) -> CGRect {
        guard let line = lineManager.value.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let lineLocalRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
        let lineContentsRect = firstRect(for: lineLocalRange, in: lineController.lineFragments)
        let visibleWidth = viewport.value.width - gutterWidthService.gutterWidth
        let xPosition = lineContentsRect.minX + textContainerInset.value.left + gutterWidthService.gutterWidth
        let yPosition = line.yPosition + lineContentsRect.minY + textContainerInset.value.top
        let width = min(lineContentsRect.width, visibleWidth)
        return CGRect(x: xPosition, y: yPosition, width: width, height: lineContentsRect.height)
    }
}

private extension FirstRectFactory {
    private func firstRect(for lineLocalRange: NSRange, in lineFragments: [LineFragment]) -> CGRect {
        for lineFragment in lineFragments {
            if let insertionPointRange = lineFragment.insertionPointRange(forLineLocalRange: lineLocalRange) {
                let finalIndex = min(lineFragment.visibleRange.upperBound, insertionPointRange.upperBound)
                let xStart = CTLineGetOffsetForStringIndex(lineFragment.line, insertionPointRange.location, nil)
                let xEnd = CTLineGetOffsetForStringIndex(lineFragment.line, finalIndex, nil)
                let yPosition = lineFragment.yPosition + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
                return CGRect(x: xStart, y: yPosition, width: xEnd - xStart, height: lineFragment.baseSize.height)
            }
        }
        return CGRect(x: 0, y: 0, width: 0, height: estimatedLineHeight.scaledValue.value)
    }
}
