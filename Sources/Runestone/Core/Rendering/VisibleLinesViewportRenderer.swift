import Foundation
import _RunestoneObservation

@RunestoneObserver
final class VisibleLinesViewportRenderer<
    ViewportType: Viewport,
    LineManagerType: LineManaging,
    VisibleLinesRenderingType: VisibleLinesRendering
>: ViewportRendering where VisibleLinesRenderingType.LineType == LineManagerType.LineType {
    private var viewport: ViewportType
    private let lineManager: LineManagerType
    private let visibleLinesRenderer: VisibleLinesRenderingType

    init(
        viewport: ViewportType,
        lineManager: LineManagerType,
        visibleLinesRenderer: VisibleLinesRenderingType
    ) {
        self.viewport = viewport
        self.lineManager = lineManager
        self.visibleLinesRenderer = visibleLinesRenderer
        observe(viewport.origin) { [weak self] _, _ in
            self?.renderViewport()
        }
        observe(viewport.size) { [weak self] _, _ in
            self?.invalidateAllTypesetText()
            self?.renderViewport()
        }
    }

    func renderViewport() {
        var visibleLines: [VisibleLine<LineManagerType.LineType>] = []
        var workingLine: LineManagerType.LineType? = lineManager.line(atYOffset: viewport.minY)
        while let line = workingLine {
            line.typesetText(toYOffset: viewport.maxY)
            let lineFragments = line.lineFragments(in: viewport.rect)
            let visibleLine = VisibleLine(line: line, lineFragments: lineFragments)
            visibleLines.append(visibleLine)
            let lineIndex = line.index
            let isWithinViewport = line.yPosition + line.height < viewport.maxY
            let hasMoreLines = lineIndex < lineManager.lineCount - 1
            workingLine = if isWithinViewport && hasMoreLines && !lineFragments.isEmpty {
                lineManager[lineIndex + 1]
            } else {
                nil
            }
        }
        visibleLinesRenderer.renderVisibleLines(visibleLines)
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
}

private extension VisibleLinesViewportRenderer {
    private func invalidateAllTypesetText() {
        for line in lineManager {
            line.invalidateTypesetText()
        }
    }
}
