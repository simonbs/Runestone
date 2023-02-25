import Foundation

extension TextViewController {
    func layoutPageGuideIfNeeded() {
        guard showPageGuide else {
            return
        }
        // The width extension is used to make the page guide look "attached" to the right hand side, even when the scroll view bouncing on the right side.
        let maxContentOffsetX = contentSizeService.contentWidth - viewport.width
        let widthExtension = max(ceil(viewport.minX - maxContentOffsetX), 0)
        let xPosition = gutterWidthService.gutterWidth + textContainerInset.left + pageGuideController.columnOffset
        let width = max(contentSizeService.contentWidth - xPosition + widthExtension, 0)
        let origin = CGPoint(x: xPosition, y: viewport.minY)
        let pageGuideSize = CGSize(width: width, height: viewport.height)
        pageGuideController.guideView.frame = CGRect(origin: origin, size: pageGuideSize)
    }
}
