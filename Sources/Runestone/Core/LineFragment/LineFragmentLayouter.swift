//import Combine
//import CoreGraphics
//import Foundation

//final class LineFragmentLayouter<StringViewType: StringView, LineManagerType: LineManaging> {
//    private(set) var visibleLineIDs: Set<LineNodeID> = []
//
//    private let stringView: StringViewType
//    private let lineManager: LineManagerType
//    private let lineControllerStore: LineControllerStoring
//    private let widestLineTracker: WidestLineTracker
//    private let totalLineHeightTracker: TotalLineHeightTracker
//    private let textContainer: TextContainer
//    private let isLineWrappingEnabled: CurrentValueSubject<Bool, Never>
//    private let maximumLineBreakSymbolWidth: CurrentValueSubject<CGFloat, Never>
//    private let contentSize: CurrentValueSubject<CGSize, Never>
//    private var lineFragmentReusableViewQueue = ReusableViewQueue<LineFragmentID, LineFragmentView>()
//    private var needsLayout = false
//    private var cancellables: Set<AnyCancellable> = []
//
//    init(
//        stringView: StringViewType,
//        lineManager: LineManagerType,
//        lineControllerStore: LineControllerStoring,
//        widestLineTracker: WidestLineTracker,
//        totalLineHeightTracker: TotalLineHeightTracker,
//        textContainer: TextContainer,
//        isLineWrappingEnabled: CurrentValueSubject<Bool, Never>,
//        maximumLineBreakSymbolWidth: CurrentValueSubject<CGFloat, Never>,
//        contentSize: CurrentValueSubject<CGSize, Never>
//    ) {
//        self.stringView = stringView
//        self.lineManager = lineManager
//        self.lineControllerStore = lineControllerStore
//        self.widestLineTracker = widestLineTracker
//        self.totalLineHeightTracker = totalLineHeightTracker
//        self.textContainer = textContainer
//        self.isLineWrappingEnabled = isLineWrappingEnabled
//        self.maximumLineBreakSymbolWidth = maximumLineBreakSymbolWidth
//        self.contentSize = contentSize
//        setupSetNeedsLayoutObserver()
////        stringView.sink { [weak self] _ in
////            self?.needsLayout = true
////        }.store(in: &cancellables)
//    }
//
//    func setNeedsLayout() {
//        needsLayout = true
//    }
//
//    func layoutIfNeeded() {
//        if needsLayout {
//            needsLayout = false
//            layoutLinesInViewport()
//        }
//    }
//
//    func layoutLines(toLocation location: Int) {
////        var nextLine: LineNode? = lineManager.firstLine
////        let isLocationEndOfString = location >= stringView.string.length
////        while let line = nextLine {
////            let lineLocation = line.location
////            let endTypesettingLocation = min(lineLocation + line.data.length, location) - lineLocation
////            let lineController = lineControllerStore.getOrCreateLineController(for: line)
////            lineController.constrainingWidth = constrainingLineWidth
////            lineController.prepareToDisplayString(to: .location(endTypesettingLocation), syntaxHighlightAsynchronously: true)
////            widestLineTracker.setWidthOfLine(withID: lineController.line.id.id, to: lineController.lineWidth)
////            totalLineHeightTracker.setHeight(of: lineController.line, to: lineController.lineHeight)
////            let lineEndLocation = lineLocation + line.data.length
////            if (
////                (lineEndLocation < location) || (lineLocation == location && !isLocationEndOfString)
////            ) && line.index < lineManager.lineCount - 1 {
////                nextLine = lineManager.line(atRow: line.index + 1)
////            } else {
////                nextLine = nil
////            }
////        }
//    }
//}
//
//// MARK: - Layout
//extension LineFragmentLayouter {
//    // swiftlint:disable:next function_body_length
//    private func layoutLinesInViewport() {
////        let viewport = textContainer.viewport.value
////        guard viewport.size.width > 0 && viewport.size.height > 0 else {
////            return
////        }
////        let oldVisibleLineIDs = visibleLineIDs
////        let oldVisibleLineFragmentIDs = Set(lineFragmentReusableViewQueue.visibleViews.keys)
////        // Layout lines until we have filled the viewport.
////        var nextLine = lineManager.line(containingYOffset: viewport.minY)
////        var appearedLineIDs: Set<LineNodeID> = []
////        var appearedLineFragmentIDs: Set<LineFragmentID> = []
////        var maxY = viewport.minY
////        var contentOffsetAdjustmentY: CGFloat = 0
////        while let line = nextLine, maxY < viewport.maxY, constrainingLineWidth > 0 {
////            appearedLineIDs.insert(line.id)
////            // Prepare to line controller to display text.
////            let lineLocalViewport = CGRect(x: 0, y: maxY, width: viewport.width, height: viewport.maxY - maxY)
////            let lineController = lineControllerStore.getOrCreateLineController(for: line)
////            let oldLineHeight = lineController.lineHeight
////            lineController.constrainingWidth = constrainingLineWidth
////            lineController.prepareToDisplayString(to: .yPosition(lineLocalViewport.maxY), syntaxHighlightAsynchronously: true)
////            // Layout line fragments in the line until we have filled the viewport.
////            let lineFragmentControllers = lineController.lineFragmentControllers(in: viewport)
////            for lineFragmentController in lineFragmentControllers {
////                let lineFragment = lineFragmentController.lineFragment
////                var lineFragmentFrame: CGRect = .zero
////                appearedLineFragmentIDs.insert(lineFragment.id)
//////                lineFragmentController.highlightedRangeFragments = highlightedRangeService.highlightedRangeFragments(
//////                    for: lineFragment,
//////                    inLineWithID: line.id
//////                )
////                layoutLineFragmentView(for: lineFragmentController, lineYPosition: line.yPosition, lineFragmentFrame: &lineFragmentFrame)
////                maxY = lineFragmentFrame.maxY
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
////        // Update the visible lines and line fragments. Clean up everything that is not in the viewport anymore.
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
//
//    private func layoutLineFragmentView(
//        for lineFragmentController: LineFragmentController,
//        lineYPosition: CGFloat,
//        lineFragmentFrame: inout CGRect
//    ) {
////        let lineFragment = lineFragmentController.lineFragment
////        let lineFragmentView = lineFragmentReusableViewQueue.dequeueView(forKey: lineFragment.id)
////        if lineFragmentView.superview == nil {
////            proxyContainerView.view?.addSubview(lineFragmentView)
////        }
////        lineFragmentController.lineFragmentView = lineFragmentView
////        let textContainerInset = textContainer.inset.value
////        let lineFragmentOrigin = CGPoint(x: textContainerInset.left, y: textContainerInset.top + lineYPosition + lineFragment.yPosition)
////        let lineFragmentSize = CGSize(width: lineFragment.scaledSize.width + maximumLineBreakSymbolWidth.value, height: lineFragment.scaledSize.height)
////        let lineFragmentWidth = contentSize.value.width - textContainerInset.left - textContainerInset.right
////        let lineFragmentSize = CGSize(width: lineFragmentWidth, height: lineFragment.scaledSize.height)
////        lineFragmentFrame = CGRect(origin: lineFragmentOrigin, size: lineFragmentSize)
////        lineFragmentView.frame = lineFragmentFrame
//    }
//
//    private func setupSetNeedsLayoutObserver() {
////        Publishers.CombineLatest3(
//////            stringView,
////            isLineWrappingEnabled.removeDuplicates(),
////            maximumLineBreakSymbolWidth.removeDuplicates(),
////            Publishers.CombineLatest3(
////                textContainer.viewport.removeDuplicates(),
////                textContainer.inset.removeDuplicates(),
////                textContainer.safeAreaInsets.removeDuplicates()
////            )
////        ).sink { [weak self] _, _, _ in
////            self?.needsLayout = true
////        }.store(in: &cancellables)
//    }
//}
