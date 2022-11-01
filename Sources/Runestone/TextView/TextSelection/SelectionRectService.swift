import UIKit

final class SelectionRectService {
    var lineManager: LineManager
    var textContainerInset: UIEdgeInsets = .zero
    var lineHeightMultiplier: CGFloat = 1

    private let contentSizeService: ContentSizeService
    private let gutterWidthService: GutterWidthService
    private let caretRectService: CaretRectService

    init(lineManager: LineManager,
         contentSizeService: ContentSizeService,
         gutterWidthService: GutterWidthService,
         caretRectService: CaretRectService) {
        self.lineManager = lineManager
        self.contentSizeService = contentSizeService
        self.gutterWidthService = gutterWidthService
        self.caretRectService = caretRectService
    }

    func selectionRects(in range: NSRange) -> [TextSelectionRect] {
        guard range.length > 0 else {
            return []
        }
        guard let endLine = lineManager.line(containingCharacterAt: range.upperBound) else {
            return []
        }
        let leadingLineSpacing = gutterWidthService.gutterWidth + textContainerInset.left
        let selectsLineEnding = range.upperBound == endLine.location
        let adjustedRange = NSRange(location: range.location, length: selectsLineEnding ? range.length - 1 : range.length)
        let startCaretRect = caretRectService.caretRect(at: adjustedRange.lowerBound, allowMovingCaretToNextLineFragment: true)
        let endCaretRect = caretRectService.caretRect(at: adjustedRange.upperBound, allowMovingCaretToNextLineFragment: false)
        let fullWidth = max(contentSizeService.contentWidth, contentSizeService.scrollViewWidth) - leadingLineSpacing - textContainerInset.right
        if startCaretRect.minY == endCaretRect.minY && startCaretRect.maxY == endCaretRect.maxY {
            // Selecting text in the same line fragment.
            let width = selectsLineEnding ? fullWidth - (startCaretRect.minX - leadingLineSpacing) : endCaretRect.maxX - startCaretRect.maxX
            let scaledHeight = startCaretRect.height * lineHeightMultiplier
            let offsetY = startCaretRect.minY - (scaledHeight - startCaretRect.height) / 2
            let rect = CGRect(x: startCaretRect.minX, y: offsetY, width: width, height: scaledHeight)
            let selectionRect = TextSelectionRect(rect: rect, writingDirection: .natural, containsStart: true, containsEnd: true)
            return [selectionRect]
        } else {
            // Selecting text across line fragments and possibly across lines.
            let startWidth = fullWidth - (startCaretRect.minX - leadingLineSpacing)
            let startScaledHeight = startCaretRect.height * lineHeightMultiplier
            let startOffsetY = startCaretRect.minY - (startScaledHeight - startCaretRect.height) / 2
            let startRect = CGRect(x: startCaretRect.minX, y: startOffsetY, width: startWidth, height: startScaledHeight)
            let endWidth = selectsLineEnding ? fullWidth : endCaretRect.minX - leadingLineSpacing
            let endScaledHeight = endCaretRect.height * lineHeightMultiplier
            let endOffsetY = endCaretRect.minY - (endScaledHeight - endCaretRect.height) / 2
            let endRect = CGRect(x: leadingLineSpacing, y: endOffsetY, width: endWidth, height: endScaledHeight)
            let middleHeight = endRect.minY - startRect.maxY
            let middleRect = CGRect(x: leadingLineSpacing, y: startRect.maxY, width: fullWidth, height: middleHeight)
            let startSelectionRect = TextSelectionRect(rect: startRect, writingDirection: .natural, containsStart: true, containsEnd: false)
            let middleSelectionRect = TextSelectionRect(rect: middleRect, writingDirection: .natural, containsStart: false, containsEnd: false)
            let endSelectionRect = TextSelectionRect(rect: endRect, writingDirection: .natural, containsStart: false, containsEnd: true)
            return [startSelectionRect, middleSelectionRect, endSelectionRect]
        }
    }
}
