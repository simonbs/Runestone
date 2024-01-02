//import Combine
//import CoreGraphics
//import Foundation
//
//final class LineTextViewChildLayouter<LineManagerType: LineManaging> {
////    private(set) var visibleLineIDs: Set<LineNodeID> = []
////
////    private let proxyScrollView: ProxyScrollView
////    private let stringView: any StringView
////    private let lineManager: LineManaging
////    private let lineControllerStore: LineControllerStoring
////    private let widestLineTracker: WidestLineTracker
////    private let totalLineHeightTracker: TotalLineHeightTracker
////    private let textContainer: TextContainer
////    private let isLineWrappingEnabled: CurrentValueSubject<Bool, Never>
////    private let maximumLineBreakSymbolWidth: CurrentValueSubject<CGFloat, Never>
////    private let contentSize: CurrentValueSubject<CGSize, Never>
////    private var needsLayout = false
////    private var cancellables: Set<AnyCancellable> = []
////    private var constrainingLineWidth: CGFloat {
////        if isLineWrappingEnabled.value {
////            let horizontalContainerInset = textContainer.inset.value.left + textContainer.inset.value.right
////            let horizontalSafeAreaInset = textContainer.safeAreaInsets.value.left + textContainer.safeAreaInsets.value.right
////            return textContainer.viewport.value.width - horizontalContainerInset - horizontalSafeAreaInset
////        } else {
////            // Rendering multiple very long lines is very expensive. In order to let the editor remain useable,
////            // we set a very high maximum line width when line wrapping is disabled.
////            return 10_000
////        }
////    }
////    private var scrollView: MultiPlatformScrollView? {
////        _scrollView.value.value
////    }
//
////    init(
////        proxyScrollView: ProxyScrollView,
////        stringView: any StringView,
////        lineManager: LineManaging,
////        lineControllerStore: LineControllerStoring,
////        widestLineTracker: WidestLineTracker,
////        totalLineHeightTracker: TotalLineHeightTracker,
////        textContainer: TextContainer,
////        isLineWrappingEnabled: CurrentValueSubject<Bool, Never>,
////        maximumLineBreakSymbolWidth: CurrentValueSubject<CGFloat, Never>,
////        contentSize: CurrentValueSubject<CGSize, Never>
////    ) {
////        self._scrollView = scrollView
////        self.stringView = stringView
////        self.lineManager = lineManager
////        self.lineControllerStore = lineControllerStore
////        self.widestLineTracker = widestLineTracker
////        self.totalLineHeightTracker = totalLineHeightTracker
////        self.textContainer = textContainer
////        self.isLineWrappingEnabled = isLineWrappingEnabled
////        self.maximumLineBreakSymbolWidth = maximumLineBreakSymbolWidth
////        self.contentSize = contentSize
////    }
//
////    private let viewport: Viewport
////    private let lineManager: LineManagerType
////    private let visibleLineLayouter: VisibleLineLayouter
////
////    init(
////        viewport: Viewport,
////        lineManager: LineManagerType,
////        visibleLineLayouter: VisibleLineLayouter
////    ) {
////        self.viewport = viewport
////        self.lineManager = lineManager
////        self.visibleLineLayouter = visibleLineLayouter
////    }
//}
//
//// MARK: - Layout
//extension LineTextViewChildLayouter {
//    // swiftlint:disable:next function_body_length
//    private func layoutLinesInViewport() {
////        guard viewport.width > 0 && viewport.height > 0 else {
////            return
////        }
////        let textContainerInset = textContainer.inset.value
////        let oldVisibleLineIDs = visibleLineIDs
////        let oldVisibleLineFragmentIDs = Set(lineFragmentReusableViewQueue.visibleViews.keys)
////        var nextLine = lineManager.line(containingYOffset: viewport.minY)
////        var appearedLineIDs: Set<LineNodeID> = []
////        var appearedLineFragmentIDs: Set<LineFragmentID> = []
////        var maxY = viewport.minY
////        var contentOffsetAdjustmentY: CGFloat = 0
////        while let line = nextLine, maxY < viewport.maxY {
////            appearedLineIDs.insert(line.id)
//            // Prepare to line controller to display text.
////            let lineLocalViewport = CGRect(x: 0, y: maxY, width: viewport.width, height: viewport.maxY - maxY)
////            let lineController = lineControllerStore.getOrCreateLineController(for: line)
////            let oldLineHeight = lineController.lineHeight
////            lineController.constrainingWidth = constrainingLineWidth
////            lineController.prepareToDisplayString(to: .yPosition(lineLocalViewport.maxY), syntaxHighlightAsynchronously: true)
//            // Layout line fragments in the line until we have filled the viewport.
////            let lineFragmentControllers = lineController.lineFragmentControllers(in: viewport)
////            for lineFragmentController in lineFragmentControllers {
////                let lineFragment = lineFragmentController.lineFragment
//////                var lineFragmentFrame: CGRect = .zero
////                appearedLineFragmentIDs.insert(lineFragment.id)
//////                layoutLineFragmentView(for: lineFragmentController, lineYPosition: line.yPosition, lineFragmentFrame: &lineFragmentFrame)
////                let lineFragmentOrigin = CGPoint(x: textContainerInset.left, y: textContainerInset.top + line.yPosition + lineFragment.yPosition)
////                let lineFragmentSize = CGSize(width: lineFragment.scaledSize.width + maximumLineBreakSymbolWidth.value, height: lineFragment.scaledSize.height)
////                let lineFragmentRect = CGRect(origin: lineFragmentOrigin, size: lineFragmentSize)
////                maxY = lineFragmentRect.maxY
////            }
////            widestLineTracker.setWidthOfLine(withID: lineController.line.id.id, to: lineController.lineWidth)
////            totalLineHeightTracker.setHeight(of: lineController.line, to: lineController.lineHeight)
////            let isSizingLineAboveTopEdge = line.yPosition < viewport.minY
////            if isSizingLineAboveTopEdge && lineController.isFinishedTypesetting {
////                contentOffsetAdjustmentY += lineController.lineHeight - oldLineHeight
////            }
////            if !lineFragmentControllers.isEmpty && line.index < lineManager.lineCount - 1 {
////                nextLine = lineManager.line(atRow: line.index + 1)
////            } else {
////                nextLine = nil
////            }
////        }
//        // Update the visible lines and line fragments. Clean up everything that is not in the viewport anymore.
////        visibleLineIDs = appearedLineIDs
////        let disappearedLineIDs = oldVisibleLineIDs.subtracting(appearedLineIDs)
////        let disappearedLineFragmentIDs = oldVisibleLineFragmentIDs.subtracting(appearedLineFragmentIDs)
////        for disappearedLineID in disappearedLineIDs {
////            let lineController = LineControllerStore[disappearedLineID]
////            lineController?.cancelSyntaxHighlighting()
////        }
////        lineFragmentReusableViewQueue.enqueueViews(withKeys: disappearedLineFragmentIDs)
////        // Adjust the content offset on the Y-axis if necessary.
////        if contentOffsetAdjustmentY != 0, let scrollView, (scrollView.isDragging || scrollView.isDecelerating) {
////            scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: scrollView.contentOffset.y + contentOffsetAdjustmentY)
////        }
//    }
//}
