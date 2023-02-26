import CoreGraphics
import Foundation

protocol LineFragmentLayoutManagerDelegate: AnyObject {
    func lineFragmentLayoutManager(_ lineFragmentLayoutManager: LineFragmentLayoutManager, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint)
}

final class LineFragmentLayoutManager {
    weak var delegate: LineFragmentLayoutManagerDelegate?
    var viewport: CGRect = .zero {
        didSet {
            if viewport != oldValue {
                setNeedsLayout()
            }
        }
    }
    var isLineWrappingEnabled = true {
        didSet {
            if isLineWrappingEnabled != oldValue {
                setNeedsLayout()
            }
        }
    }
    var textContainerInset: MultiPlatformEdgeInsets = .zero {
        didSet {
            if textContainerInset != oldValue {
                setNeedsLayout()
            }
        }
    }
    var safeAreaInsets: MultiPlatformEdgeInsets = .zero {
        didSet {
            if safeAreaInsets != oldValue {
                setNeedsLayout()
            }
        }
    }
    private(set) var visibleLineIDs: Set<LineNodeID> = []

    private let stringView: StringView
    private let lineManager: LineManager
    private let lineControllerStorage: LineControllerStorage
    private let contentSizeService: ContentSizeService
    private weak var containerView: MultiPlatformView?
    private var lineFragmentReusableViewQueue = ReusableViewQueue<LineFragmentID, LineFragmentView>()
    private var needsLayout = false
    private var constrainingLineWidth: CGFloat {
        if isLineWrappingEnabled {
            return viewport.width
            - textContainerInset.left - textContainerInset.right
            - safeAreaInsets.left - safeAreaInsets.right
            //            - verticalScrollerWidth
        } else {
            // Rendering multiple very long lines is very expensive. In order to let the editor remain useable,
            // we set a very high maximum line width when line wrapping is disabled.
            return 10_000
        }
    }

    init(
        stringView: StringView,
        lineManager: LineManager,
        lineControllerStorage: LineControllerStorage,
        contentSizeService: ContentSizeService,
        containerView: MultiPlatformView
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.contentSizeService = contentSizeService
        self.containerView = containerView
    }

    func setNeedsLayout() {
        needsLayout = true
    }

    func layoutIfNeeded() {
        guard needsLayout else {
            return
        }
        needsLayout = false
        layoutLinesInViewport()
    }

    func layoutLines(toLocation location: Int) {
        var nextLine: LineNode? = lineManager.firstLine
        let isLocationEndOfString = location >= stringView.string.length
        while let line = nextLine {
            let lineLocation = line.location
            let endTypesettingLocation = min(lineLocation + line.data.length, location) - lineLocation
            let lineController = lineControllerStorage.getOrCreateLineController(for: line)
            lineController.constrainingWidth = constrainingLineWidth
            lineController.prepareToDisplayString(toLocation: endTypesettingLocation, syntaxHighlightAsynchronously: true)
            let lineSize = CGSize(width: lineController.lineWidth, height: lineController.lineHeight)
            contentSizeService.setSize(of: lineController.line, to: lineSize)
            let lineEndLocation = lineLocation + line.data.length
            if ((lineEndLocation < location) || (lineLocation == location && !isLocationEndOfString)) && line.index < lineManager.lineCount - 1 {
                nextLine = lineManager.line(atRow: line.index + 1)
            } else {
                nextLine = nil
            }
        }
    }
}

// MARK: - Layout
extension LineFragmentLayoutManager {
    // swiftlint:disable:next function_body_length
    private func layoutLinesInViewport() {
        guard viewport.size.width > 0 && viewport.size.height > 0 else {
            return
        }
        let oldVisibleLineIDs = visibleLineIDs
        let oldVisibleLineFragmentIDs = Set(lineFragmentReusableViewQueue.visibleViews.keys)
        // Layout lines until we have filled the viewport.
        var nextLine = lineManager.line(containingYOffset: viewport.minY)
        var appearedLineIDs: Set<LineNodeID> = []
        var appearedLineFragmentIDs: Set<LineFragmentID> = []
        var maxY = viewport.minY
        var contentOffsetAdjustmentY: CGFloat = 0
        while let line = nextLine, maxY < viewport.maxY, constrainingLineWidth > 0 {
            appearedLineIDs.insert(line.id)
            // Prepare to line controller to display text.
            let lineLocalViewport = CGRect(x: 0, y: maxY, width: viewport.width, height: viewport.maxY - maxY)
            let lineController = lineControllerStorage.getOrCreateLineController(for: line)
            let oldLineHeight = lineController.lineHeight
            lineController.constrainingWidth = constrainingLineWidth
            lineController.prepareToDisplayString(toYPosition: lineLocalViewport.maxY, syntaxHighlightAsynchronously: true)
            // Layout line fragments ("sublines") in the line until we have filled the viewport.
            let lineYPosition = line.yPosition
            let lineFragmentControllers = lineController.lineFragmentControllers(in: viewport)
            for lineFragmentController in lineFragmentControllers {
                let lineFragment = lineFragmentController.lineFragment
                var lineFragmentFrame: CGRect = .zero
                appearedLineFragmentIDs.insert(lineFragment.id)
//                lineFragmentController.highlightedRangeFragments = highlightedRangeService.highlightedRangeFragments(
//                    for: lineFragment,
//                    inLineWithID: line.id
//                )
                layoutLineFragmentView(for: lineFragmentController, lineYPosition: lineYPosition, lineFragmentFrame: &lineFragmentFrame)
                maxY = lineFragmentFrame.maxY
            }
            let stoppedGeneratingLineFragments = lineFragmentControllers.isEmpty
            let lineSize = CGSize(width: lineController.lineWidth, height: lineController.lineHeight)
            contentSizeService.setSize(of: lineController.line, to: lineSize)
            let isSizingLineAboveTopEdge = line.yPosition < viewport.minY
            if isSizingLineAboveTopEdge && lineController.isFinishedTypesetting {
                contentOffsetAdjustmentY += lineController.lineHeight - oldLineHeight
            }
            if !stoppedGeneratingLineFragments && line.index < lineManager.lineCount - 1 {
                nextLine = lineManager.line(atRow: line.index + 1)
            } else {
                nextLine = nil
            }
        }
        // Update the visible lines and line fragments. Clean up everything that is not in the viewport anymore.
        visibleLineIDs = appearedLineIDs
        let disappearedLineIDs = oldVisibleLineIDs.subtracting(appearedLineIDs)
        let disappearedLineFragmentIDs = oldVisibleLineFragmentIDs.subtracting(appearedLineFragmentIDs)
        for disappearedLineID in disappearedLineIDs {
            let lineController = lineControllerStorage[disappearedLineID]
            lineController?.cancelSyntaxHighlighting()
        }
        lineFragmentReusableViewQueue.enqueueViews(withKeys: disappearedLineFragmentIDs)
        // Adjust the content offset on the Y-axis if necessary.
        if contentOffsetAdjustmentY != 0 {
            let contentOffsetAdjustment = CGPoint(x: 0, y: contentOffsetAdjustmentY)
            delegate?.lineFragmentLayoutManager(self, didProposeContentOffsetAdjustment: contentOffsetAdjustment)
        }
    }

    private func layoutLineFragmentView(
        for lineFragmentController: LineFragmentController,
        lineYPosition: CGFloat,
        lineFragmentFrame: inout CGRect
    ) {
        let lineFragment = lineFragmentController.lineFragment
        let lineFragmentView = lineFragmentReusableViewQueue.dequeueView(forKey: lineFragment.id)
        lineFragmentView.layerIfLoaded?.zPosition = 50
        if lineFragmentView.superview == nil {
            containerView?.addSubview(lineFragmentView)
        }
        lineFragmentController.lineFragmentView = lineFragmentView
        let lineFragmentOrigin = CGPoint(x: textContainerInset.left, y: textContainerInset.top + lineYPosition + lineFragment.yPosition)
        let lineFragmentWidth = contentSizeService.contentWidth - textContainerInset.left - textContainerInset.right
        let lineFragmentSize = CGSize(width: lineFragmentWidth, height: lineFragment.scaledSize.height)
        lineFragmentFrame = CGRect(origin: lineFragmentOrigin, size: lineFragmentSize)
        lineFragmentView.frame = lineFragmentFrame
    }
}
