import Foundation

final class TextRenderer<
    ViewportType: Viewport,
    LineManagerType: LineManaging,
    LineTextRendererType: LineTextRendering
>: TextRendering where LineManagerType.LineType == LineTextRendererType.LineType {
    private let viewport: ViewportType
    private let lineManager: LineManagerType
    private let lineTextRenderer: LineTextRendererType

    init(
        viewport: ViewportType,
        lineManager: LineManagerType,
        lineTextRenderer: LineTextRendererType
    ) {
        self.viewport = viewport
        self.lineManager = lineManager
        self.lineTextRenderer = lineTextRenderer
    }

    func renderVisibleText() {
        var needleYOffset = viewport.minY
        var previousLine: LineManagerType.LineType?
        while let line = lineManager.line(atYOffset: needleYOffset),
              line != previousLine,
              needleYOffset < viewport.maxY {
            lineTextRenderer.renderVisibleText(in: line)
            needleYOffset = line.yPosition + line.height
            previousLine = line
        }
        //        let oldVisibleLineIDs = visibleLineIDs
        //        let oldVisibleLineFragmentIDs = Set(lineFragmentViews.visibleViews.keys)
        //        var nextLine = lineManager.line(containingYOffset: viewport.minY)
        //        var appearedLineIDs: Set<LineNodeID> = []
        //        var appearedLineFragmentIDs: Set<LineFragmentID> = []
        //        var maxY = viewport.minY
        //        var contentOffsetAdjustmentY: CGFloat = 0
        //        while let line = nextLine, maxY < viewport.maxY {
        //            appearedLineIDs.insert(line.id)
        // Prepare to line controller to display text.
        //            let lineLocalViewport = CGRect(x: 0, y: maxY, width: viewport.width, height: viewport.maxY - maxY)
        //            let lineController = lineControllerStore.getOrCreateLineController(for: line)
        //            let oldLineHeight = lineController.lineHeight
        //            lineController.constrainingWidth = constrainingLineWidth
        //            lineController.prepareToDisplayString(to: .yPosition(lineLocalViewport.maxY), syntaxHighlightAsynchronously: true)
        // Layout line fragments in the line until we have filled the viewport.
        //            let lineFragmentControllers = lineController.lineFragmentControllers(in: viewport)
        //            for lineFragmentController in lineFragmentControllers {
        //                let lineFragment = lineFragmentController.lineFragment
        //                var lineFragmentFrame: CGRect = .zero
        //                appearedLineFragmentIDs.insert(lineFragment.id)
        //                layoutLineFragmentView(for: lineFragmentController, lineYPosition: line.yPosition, lineFragmentFrame: &lineFragmentFrame)
        //                let lineFragmentOrigin = CGPoint(x: viewport.minX, y: viewport.minY + line.yPosition + lineFragment.yPosition)
        //                let lineFragmentSize = CGSize(
        //                    width: lineFragment.scaledSize.width + maximumLineBreakSymbolWidth.value,
        //                    height: lineFragment.scaledSize.height
        //                )
        //                let lineFragmentRect = CGRect(origin: lineFragmentOrigin, size: lineFragmentSize)
        //                maxY = lineFragmentRect.maxY
        //            }
        //            widestLineTracker.setWidthOfLine(withID: lineController.line.id.id, to: lineController.lineWidth)
        //            totalLineHeightTracker.setHeight(of: lineController.line, to: lineController.lineHeight)
        //            let isSizingLineAboveTopEdge = line.yPosition < viewport.minY
        //            if isSizingLineAboveTopEdge && lineController.isFinishedTypesetting {
        //                contentOffsetAdjustmentY += lineController.lineHeight - oldLineHeight
        //            }
        //            if !lineFragmentControllers.isEmpty && line.index < lineManager.lineCount - 1 {
        //                nextLine = lineManager.line(atRow: line.index + 1)
        //            } else {
        //                nextLine = nil
        //            }
        //        }
        // Update the visible lines and line fragments. Clean up everything that is not in the viewport anymore.
        //        visibleLineIDs = appearedLineIDs
        //        let disappearedLineIDs = oldVisibleLineIDs.subtracting(appearedLineIDs)
        //        let disappearedLineFragmentIDs = oldVisibleLineFragmentIDs.subtracting(appearedLineFragmentIDs)
        //        for disappearedLineID in disappearedLineIDs {
        //            let lineController = lineControllerStore[disappearedLineID]
        //            lineController?.cancelSyntaxHighlighting()
        //        }
        //        lineFragmentReusableViewQueue.enqueueViews(withKeys: disappearedLineFragmentIDs)
        // Adjust the content offset on the Y-axis if necessary.
        //        if contentOffsetAdjustmentY != 0, let scrollView, (scrollView.isDragging || scrollView.isDecelerating) {
        //            scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: scrollView.contentOffset.y + contentOffsetAdjustmentY)
        //        }
    }

    func renderText(toLocation location: Int) {}
}
