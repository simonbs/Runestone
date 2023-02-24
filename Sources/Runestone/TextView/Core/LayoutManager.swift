import CoreGraphics
import Foundation
import LineManager
import MultiPlatform
import RangeHelpers
import StringView
import QuartzCore
#if os(iOS)
import UIKit
#endif

// swiftlint:disable file_length
protocol LayoutManagerDelegate: AnyObject {
    func layoutManager(_ layoutManager: LayoutManager, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint)
}

final class LayoutManager {
    weak var delegate: LayoutManagerDelegate?
    var lineManager: LineManager
    var stringView: StringView
    var verticalScrollerWidth: CGFloat = 0
    var viewport: CGRect = .zero
    var languageMode: InternalLanguageMode {
        didSet {
            if languageMode !== oldValue {
                for lineController in lineControllerStorage {
                    lineController.invalidateSyntaxHighlighter()
                    lineController.invalidateSyntaxHighlighting()
                }
            }
        }
    }
    var theme: Theme = DefaultTheme() {
        didSet {
            if theme !== oldValue {
                gutterBackgroundView.backgroundColor = theme.gutterBackgroundColor
                gutterBackgroundView.hairlineColor = theme.gutterHairlineColor
                gutterBackgroundView.hairlineWidth = theme.gutterHairlineWidth
                invisibleCharacterConfiguration.font = theme.font
                invisibleCharacterConfiguration.textColor = theme.invisibleCharactersColor
                gutterSelectionBackgroundView.backgroundColor = theme.selectedLinesGutterBackgroundColor
                lineSelectionBackgroundView.backgroundColor = theme.selectedLineBackgroundColor
                for lineController in lineControllerStorage {
                    lineController.theme = theme
                    lineController.estimatedLineFragmentHeight = theme.font.totalLineHeight
                    lineController.invalidateSyntaxHighlighting()
                }
                setNeedsLayout()
                setNeedsLayoutLineSelection()
                layoutIfNeeded()
            }
        }
    }
    var isEditing = false {
        didSet {
            if isEditing != oldValue {
                updateShownViews()
                updateLineNumberColors()
            }
        }
    }
    var showLineNumbers = false {
        didSet {
            if showLineNumbers != oldValue {
                updateShownViews()
            }
        }
    }
    var lineSelectionDisplayType: LineSelectionDisplayType = .disabled {
        didSet {
            if lineSelectionDisplayType != oldValue {
                setNeedsLayoutLineSelection()
                layoutLineSelectionIfNeeded()
                updateShownViews()
            }
        }
    }
    var isLineWrappingEnabled = true
    /// Spacing around the text. The left-side spacing defines the distance between the text and the gutter.
    var textContainerInset: MultiPlatformEdgeInsets = .zero
    var safeAreaInsets: MultiPlatformEdgeInsets = .zero
    var selectedRange: NSRange? {
        didSet {
            if selectedRange != oldValue {
                updateShownViews()
            }
        }
    }
    var lineHeightMultiplier: CGFloat = 1
    var constrainingLineWidth: CGFloat {
        if isLineWrappingEnabled {
            return viewport.width
            - gutterWidthService.gutterWidth
            - textContainerInset.left - textContainerInset.right
            - safeAreaInsets.left - safeAreaInsets.right
            - verticalScrollerWidth
        } else {
            // Rendering multiple very long lines is very expensive. In order to let the editor remain useable,
            // we set a very high maximum line width when line wrapping is disabled.
            return 10_000
        }
    }
    var markedRange: NSRange? {
        didSet {
            if markedRange != oldValue {
                updateMarkedTextOnVisibleLines()
            }
        }
    }
    var isGutterFloatingChildOfScrollView = false {
        didSet {
            if isGutterFloatingChildOfScrollView != oldValue {
                setNeedsLayout()
            }
        }
    }

    // MARK: - Views
    let linesContainerView = FlippedView()
    let lineSelectionBackgroundView = FlippedView()
    let gutterContainerView = FlippedView()
    private var lineFragmentViewReuseQueue = ViewReuseQueue<LineFragmentID, LineFragmentView>()
    private var lineNumberLabelReuseQueue = ViewReuseQueue<LineNodeID, LineNumberView>()
    private var visibleLineIDs: Set<LineNodeID> = []
    private let gutterBackgroundView = GutterBackgroundView()
    private let gutterSelectionBackgroundView = FlippedView()
    private let lineNumbersContainerView = FlippedView()

    // MARK: - Sizing
    private var insetViewport: CGRect {
        let x = viewport.minX - textContainerInset.left
        let y = viewport.minY - textContainerInset.top
        let width = viewport.width + textContainerInset.left + textContainerInset.right
        let height = viewport.height + textContainerInset.top + textContainerInset.bottom
        return CGRect(x: x, y: y, width: width, height: height)
    }
    private let contentSizeService: ContentSizeService
    private let gutterWidthService: GutterWidthService
    private let highlightService: HighlightService

    // MARK: - Rendering
    private let invisibleCharacterConfiguration: InvisibleCharacterConfiguration
    private let lineControllerStorage: LineControllerStorage
    private var needsLayout = false
    private var needsLayoutLineSelection = false

    init(
        lineManager: LineManager,
        languageMode: InternalLanguageMode,
        stringView: StringView,
        lineControllerStorage: LineControllerStorage,
        contentSizeService: ContentSizeService,
        gutterWidthService: GutterWidthService,
        highlightService: HighlightService,
        invisibleCharacterConfiguration: InvisibleCharacterConfiguration
    ) {
        self.lineManager = lineManager
        self.languageMode = languageMode
        self.stringView = stringView
        self.invisibleCharacterConfiguration = invisibleCharacterConfiguration
        self.lineControllerStorage = lineControllerStorage
        self.contentSizeService = contentSizeService
        self.gutterWidthService = gutterWidthService
        self.highlightService = highlightService
        #if os(iOS)
        self.linesContainerView.isUserInteractionEnabled = false
        self.lineNumbersContainerView.isUserInteractionEnabled = false
        self.gutterBackgroundView.isUserInteractionEnabled = false
        self.gutterSelectionBackgroundView.isUserInteractionEnabled = false
        self.lineSelectionBackgroundView.isUserInteractionEnabled = false
        #else
        self.gutterBackgroundView.wantsLayer = true
        self.gutterSelectionBackgroundView.wantsLayer = true
        self.lineSelectionBackgroundView.wantsLayer = true
        #endif
        self.updateShownViews()
        #if os(iOS)
        subscribeToMemoryWarningNotification()
        #endif
        setupViewHierarchy()
    }

    func redisplayVisibleLines() {
        // Ensure we have the correct set of visible lines.
        setNeedsLayout()
        layoutIfNeeded()
        // Force a preparation of the lines synchronously.
        redisplayLines(withIDs: visibleLineIDs)
        setNeedsDisplayOnLines()
        // Then force a relayout of the lines.
        setNeedsLayout()
        layoutIfNeeded()
    }

    func redisplayLines(withIDs lineIDs: Set<LineNodeID>) {
        for lineID in lineIDs {
            if let lineController = lineControllerStorage[lineID] {
                lineController.invalidateString()
                lineController.invalidateTypesetting()
                lineController.invalidateSyntaxHighlighting()
                // Only display the line if it's currently visible on the screen. Otherwise it's enough to invalidate it and redisplay it later.
                if visibleLineIDs.contains(lineID) {
                    let lineYPosition = lineController.line.yPosition
                    let lineLocalViewport = CGRect(x: 0, y: lineYPosition, width: insetViewport.width, height: insetViewport.maxY - lineYPosition)
                    lineController.prepareToDisplayString(in: lineLocalViewport, syntaxHighlightAsynchronously: false)
                }
            }
        }
    }

    func setNeedsDisplayOnLines() {
        for lineController in lineControllerStorage {
            lineController.setNeedsDisplayOnLineFragmentViews()
        }
    }

    func textPreview(containing needleRange: NSRange, peekLength: Int = 50) -> TextPreview? {
        let lines = lineManager.lines(in: needleRange)
        guard !lines.isEmpty else {
            return nil
        }
        let firstLine = lines[0]
        let lastLine = lines[lines.count - 1]
        let minimumLocation = firstLine.location
        let maximumLocation = lastLine.location + lastLine.data.length
        let startLocation = max(needleRange.location - peekLength, minimumLocation)
        let endLocation = min(needleRange.location + needleRange.location + peekLength, maximumLocation)
        let previewLength = endLocation - startLocation
        let previewRange = NSRange(location: startLocation, length: previewLength)
        let lineControllers = lines.map { lineControllerStorage.getOrCreateLineController(for: $0) }
        let localNeedleLocation = needleRange.location - startLocation
        let localNeedleLength = min(needleRange.length, previewRange.length)
        let needleInPreviewRange = NSRange(location: localNeedleLocation, length: localNeedleLength)
        return TextPreview(
            needleRange: needleRange,
            previewRange: previewRange,
            needleInPreviewRange: needleInPreviewRange,
            lineControllers: lineControllers
        )
    }
}

// MARK: - UITextInput
extension LayoutManager {
    func firstRect(for range: NSRange) -> CGRect {
        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let localRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
        let lineContentsRect = lineController.firstRect(for: localRange)
        let visibleWidth = viewport.width - gutterWidthService.gutterWidth
        let xPosition = lineContentsRect.minX + textContainerInset.left + gutterWidthService.gutterWidth
        let yPosition = line.yPosition + lineContentsRect.minY + textContainerInset.top
        let width = min(lineContentsRect.width, visibleWidth)
        return CGRect(x: xPosition, y: yPosition, width: width, height: lineContentsRect.height)
    }

    func closestIndex(to point: CGPoint) -> Int {
        let adjustedXPosition = point.x - textContainerInset.left
        let adjustedYPosition = point.y - textContainerInset.top
        let adjustedPoint = CGPoint(x: adjustedXPosition, y: adjustedYPosition)
        if let line = lineManager.line(containingYOffset: adjustedPoint.y), let lineController = lineControllerStorage[line.id] {
            return closestIndex(to: adjustedPoint, in: lineController)
        } else if adjustedPoint.y <= 0 {
            let firstLine = lineManager.firstLine
            if let lineController = lineControllerStorage[firstLine.id] {
                return closestIndex(to: adjustedPoint, in: lineController)
            } else {
                return 0
            }
        } else {
            let lastLine = lineManager.lastLine
            if adjustedPoint.y >= lastLine.yPosition, let lineController = lineControllerStorage[lastLine.id] {
                return closestIndex(to: adjustedPoint, in: lineController)
            } else {
                return stringView.string.length
            }
        }
    }

    private func closestIndex(to point: CGPoint, in lineController: LineController) -> Int {
        let line = lineController.line
        let localPoint = CGPoint(x: point.x, y: point.y - line.yPosition)
        return lineController.closestIndex(to: localPoint)
    }
}

// MARK: - Layout
extension LayoutManager {
    func setNeedsLayout() {
        needsLayout = true
    }

    func layoutIfNeeded() {
        if needsLayout {
            needsLayout = false
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layoutGutter()
            layoutLinesInViewport()
            layoutLineSelection()
            updateLineNumberColors()
            CATransaction.commit()
        }
    }

    func setNeedsLayoutLineSelection() {
        needsLayoutLineSelection = true
    }

    func layoutLineSelectionIfNeeded() {
        if needsLayoutLineSelection {
            needsLayoutLineSelection = true
            CATransaction.begin()
            CATransaction.setDisableActions(false)
            layoutLineSelection()
            updateLineNumberColors()
            CATransaction.commit()
        }
    }

    #if os(iOS)
    func bringGutterToFront() {
        gutterContainerView.superview?.bringSubviewToFront(gutterContainerView)
    }
    #endif

    private func layoutGutter() {
        let totalGutterWidth = safeAreaInsets.left + gutterWidthService.gutterWidth
        let contentSize = contentSizeService.contentSize
        let gutterContainerXOffset = isGutterFloatingChildOfScrollView ? 0 : viewport.minX
        gutterContainerView.frame = CGRect(x: gutterContainerXOffset, y: 0, width: totalGutterWidth, height: contentSize.height)
        gutterBackgroundView.frame = CGRect(x: 0, y: viewport.minY, width: totalGutterWidth, height: viewport.height)
        lineNumbersContainerView.frame = CGRect(x: 0, y: 0, width: totalGutterWidth, height: contentSize.height)
    }

    private func layoutLineSelection() {
        guard let rect = getLineSelectionRect() else {
            return
        }
        let totalGutterWidth = safeAreaInsets.left + gutterWidthService.gutterWidth
        gutterSelectionBackgroundView.frame = CGRect(x: 0, y: rect.minY, width: totalGutterWidth, height: rect.height)
        let lineSelectionBackgroundOrigin = CGPoint(x: viewport.minX + totalGutterWidth, y: rect.minY)
        let lineSelectionBackgroundSize = CGSize(width: viewport.width - totalGutterWidth, height: rect.height)
        lineSelectionBackgroundView.frame = CGRect(origin: lineSelectionBackgroundOrigin, size: lineSelectionBackgroundSize)
    }

    private func getLineSelectionRect() -> CGRect? {
        guard lineSelectionDisplayType.shouldShowLineSelection, var selectedRange = selectedRange?.nonNegativeLength else {
            return nil
        }
        guard let (startLine, endLine) = lineManager.startAndEndLine(in: selectedRange) else {
            return nil
        }
        // If the line starts where our selection ends then our selection end son a line break and we will not include the following line.
        var realEndLine = endLine
        if selectedRange.upperBound == endLine.location && startLine !== endLine {
            realEndLine = endLine.previous
            selectedRange = NSRange(location: selectedRange.lowerBound, length: max(selectedRange.length - 1, 0))
        }
        switch lineSelectionDisplayType {
        case .line:
            let minY = startLine.yPosition
            let height = (realEndLine.yPosition + realEndLine.data.lineHeight) - minY
            return CGRect(x: 0, y: textContainerInset.top + minY, width: viewport.width, height: height)
        case .lineFragment:
            let caretRectFactory = CaretRectFactory(
                stringView: stringView,
                lineManager: lineManager,
                lineControllerStorage: lineControllerStorage,
                gutterWidthService: gutterWidthService,
                textContainerInset: textContainerInset
            )
            let startCaretRect = caretRectFactory.caretRect(at: selectedRange.lowerBound, allowMovingCaretToNextLineFragment: false)
            let endCaretRect = caretRectFactory.caretRect(at: selectedRange.upperBound, allowMovingCaretToNextLineFragment: false)
            let startLineFragmentHeight = startCaretRect.height * lineHeightMultiplier
            let endLineFragmentHeight = endCaretRect.height * lineHeightMultiplier
            let minY = startCaretRect.minY - (startLineFragmentHeight - startCaretRect.height) / 2
            let maxY = endCaretRect.maxY + (endLineFragmentHeight - endCaretRect.height) / 2
            return CGRect(x: 0, y: minY, width: viewport.width, height: maxY - minY)
        case .disabled:
            return nil
        }
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

    // swiftlint:disable:next function_body_length
    private func layoutLinesInViewport() {
        // Immediately bail out from generating lines in a viewport of zero size.
        guard viewport.size.width > 0 && viewport.size.height > 0 else {
            return
        }
        let oldVisibleLineIDs = visibleLineIDs
        let oldVisibleLineFragmentIDs = Set(lineFragmentViewReuseQueue.visibleViews.keys)
        // Layout lines until we have filled the viewport.
        var nextLine = lineManager.line(containingYOffset: insetViewport.minY)
        var appearedLineIDs: Set<LineNodeID> = []
        var appearedLineFragmentIDs: Set<LineFragmentID> = []
        var maxY = insetViewport.minY
        var contentOffsetAdjustmentY: CGFloat = 0
        while let line = nextLine, maxY < insetViewport.maxY, constrainingLineWidth > 0 {
            appearedLineIDs.insert(line.id)
            // Prepare to line controller to display text.
            let lineLocalViewport = CGRect(x: 0, y: maxY, width: insetViewport.width, height: insetViewport.maxY - maxY)
            let lineController = lineControllerStorage.getOrCreateLineController(for: line)
            let oldLineHeight = lineController.lineHeight
            lineController.constrainingWidth = constrainingLineWidth
            lineController.prepareToDisplayString(in: lineLocalViewport, syntaxHighlightAsynchronously: true)
            layoutLineNumberView(for: line)
            // Layout line fragments ("sublines") in the line until we have filled the viewport.
            let lineYPosition = line.yPosition
            let lineFragmentControllers = lineController.lineFragmentControllers(in: insetViewport)
            for lineFragmentController in lineFragmentControllers {
                let lineFragment = lineFragmentController.lineFragment
                var lineFragmentFrame: CGRect = .zero
                appearedLineFragmentIDs.insert(lineFragment.id)
                lineFragmentController.highlightedRangeFragments = highlightService.highlightedRangeFragments(
                    for: lineFragment,
                    inLineWithID: line.id
                )
                layoutLineFragmentView(for: lineFragmentController, lineYPosition: lineYPosition, lineFragmentFrame: &lineFragmentFrame)
                maxY = lineFragmentFrame.maxY
            }
            // The line fragments have now been created and we can set the marked and highlighted ranges on them.
            if let markedRange = markedRange {
                let lineRange = NSRange(location: lineController.line.location, length: lineController.line.data.totalLength)
                let localMarkedRange = markedRange.local(to: lineRange)
                lineController.setMarkedTextOnLineFragments(localMarkedRange)
            } else {
                lineController.setMarkedTextOnLineFragments(nil)
            }
            let stoppedGeneratingLineFragments = lineFragmentControllers.isEmpty
            let lineSize = CGSize(width: lineController.lineWidth, height: lineController.lineHeight)
            contentSizeService.setSize(of: lineController.line, to: lineSize)
            let isSizingLineAboveTopEdge = line.yPosition < insetViewport.minY + textContainerInset.top
            if isSizingLineAboveTopEdge && lineController.isFinishedTypesetting {
                contentOffsetAdjustmentY += lineController.lineHeight - oldLineHeight
            }
            if !stoppedGeneratingLineFragments && line.index < lineManager.lineCount - 1 {
                nextLine = lineManager.line(atRow: line.index + 1)
            } else {
                nextLine = nil
            }
        }
        let contentSize = contentSizeService.contentSize
        let totalGutterWidth = safeAreaInsets.left + gutterWidthService.gutterWidth
        linesContainerView.frame = CGRect(x: max(viewport.minX, 0) + totalGutterWidth, y: 0, width: contentSize.width, height: contentSize.height)
        // Update the visible lines and line fragments. Clean up everything that is not in the viewport anymore.
        visibleLineIDs = appearedLineIDs
        let disappearedLineIDs = oldVisibleLineIDs.subtracting(appearedLineIDs)
        let disappearedLineFragmentIDs = oldVisibleLineFragmentIDs.subtracting(appearedLineFragmentIDs)
        for disappearedLineID in disappearedLineIDs {
            let lineController = lineControllerStorage[disappearedLineID]
            lineController?.cancelSyntaxHighlighting()
        }
        lineNumberLabelReuseQueue.enqueueViews(withKeys: disappearedLineIDs)
        lineFragmentViewReuseQueue.enqueueViews(withKeys: disappearedLineFragmentIDs)
        // Adjust the content offset on the Y-axis if necessary.
        if contentOffsetAdjustmentY != 0 {
            let contentOffsetAdjustment = CGPoint(x: 0, y: contentOffsetAdjustmentY)
            delegate?.layoutManager(self, didProposeContentOffsetAdjustment: contentOffsetAdjustment)
        }
    }

    private func layoutLineNumberView(for line: LineNode) {
        let lineNumberView = lineNumberLabelReuseQueue.dequeueView(forKey: line.id)
        if lineNumberView.superview == nil {
            lineNumbersContainerView.addSubview(lineNumberView)
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let fontLineHeight = theme.lineNumberFont.lineHeight
        let xPosition = safeAreaInsets.left + gutterWidthService.gutterLeadingPadding
        var yPosition = textContainerInset.top + line.yPosition
        if lineController.numberOfLineFragments > 1 {
            // There are more than one line fragments, so we align the line number at the top.
            yPosition += (fontLineHeight * lineHeightMultiplier - fontLineHeight) / 2
        } else {
            // There's a single line fragment, so we center the line number in the height of the line.
            yPosition += (lineController.lineHeight - fontLineHeight) / 2
        }
        lineNumberView.text = "\(line.index + 1)"
        lineNumberView.font = theme.lineNumberFont
        lineNumberView.textColor = theme.lineNumberColor
        lineNumberView.frame = CGRect(x: xPosition, y: yPosition, width: gutterWidthService.lineNumberWidth, height: fontLineHeight)
    }

    private func layoutLineFragmentView(
        for lineFragmentController: LineFragmentController,
        lineYPosition: CGFloat,
        lineFragmentFrame: inout CGRect
    ) {
        let lineFragment = lineFragmentController.lineFragment
        let lineFragmentView = lineFragmentViewReuseQueue.dequeueView(forKey: lineFragment.id)
        if lineFragmentView.superview == nil {
            linesContainerView.addSubview(lineFragmentView)
        }
        lineFragmentController.lineFragmentView = lineFragmentView
        let lineFragmentXOffset = max(viewport.minX, 0) * -1 + textContainerInset.left
        let lineFragmentYOffset = textContainerInset.top + lineYPosition + lineFragment.yPosition
        let lineFragmentOrigin = CGPoint(x: lineFragmentXOffset, y: lineFragmentYOffset)
        let lineFragmentWidth = contentSizeService.contentWidth - textContainerInset.left - textContainerInset.right
        let lineFragmentSize = CGSize(width: lineFragmentWidth, height: lineFragment.scaledSize.height)
        lineFragmentFrame = CGRect(origin: lineFragmentOrigin, size: lineFragmentSize)
        lineFragmentView.frame = lineFragmentFrame
    }

    private func updateLineNumberColors() {
        let visibleViews = lineNumberLabelReuseQueue.visibleViews
        let selectionFrame = gutterSelectionBackgroundView.frame
        let isSelectionVisible = !gutterSelectionBackgroundView.isHidden
        for (_, lineNumberView) in visibleViews {
            if isSelectionVisible {
                let lineNumberFrame = lineNumberView.frame
                let isInSelection = lineNumberFrame.midY >= selectionFrame.minY && lineNumberFrame.midY <= selectionFrame.maxY
                lineNumberView.textColor = isInSelection && isEditing ? theme.selectedLinesLineNumberColor : theme.lineNumberColor
            } else {
                lineNumberView.textColor = theme.lineNumberColor
            }
        }
    }

    private func setupViewHierarchy() {
        // Remove views from view hierarchy
        lineSelectionBackgroundView.removeFromSuperview()
        linesContainerView.removeFromSuperview()
        gutterBackgroundView.removeFromSuperview()
        gutterSelectionBackgroundView.removeFromSuperview()
        lineNumbersContainerView.removeFromSuperview()
        let allLineNumberKeys = lineFragmentViewReuseQueue.visibleViews.keys
        lineFragmentViewReuseQueue.enqueueViews(withKeys: Set(allLineNumberKeys))
        // Add views to view hierarchy
        gutterContainerView.addSubview(gutterBackgroundView)
        gutterContainerView.addSubview(gutterSelectionBackgroundView)
        gutterContainerView.addSubview(lineNumbersContainerView)
    }

    private func updateShownViews() {
        let selectedLength = selectedRange?.length ?? 0
        gutterBackgroundView.isHidden = !showLineNumbers
        lineNumbersContainerView.isHidden = !showLineNumbers
        gutterSelectionBackgroundView.isHidden = !lineSelectionDisplayType.shouldShowLineSelection || !showLineNumbers || !isEditing
        lineSelectionBackgroundView.isHidden = !lineSelectionDisplayType.shouldShowLineSelection || !isEditing || selectedLength != 0
    }
}

// MARK: - Marked Text
private extension LayoutManager {
    private func updateMarkedTextOnVisibleLines() {
        for lineID in visibleLineIDs {
            if let lineController = lineControllerStorage[lineID] {
                if let markedRange = markedRange {
                    let lineRange = NSRange(location: lineController.line.location, length: lineController.line.data.totalLength)
                    let localMarkedRange = markedRange.local(to: lineRange)
                    lineController.setMarkedTextOnLineFragments(localMarkedRange)
                } else {
                    lineController.setMarkedTextOnLineFragments(nil)
                }
            }
        }
    }
}

// MARK: - Memory Management
#if os(iOS)
private extension LayoutManager {
    private func subscribeToMemoryWarningNotification() {
        let memoryWarningNotificationName = UIApplication.didReceiveMemoryWarningNotification
        NotificationCenter.default.addObserver(self, selector: #selector(clearMemory), name: memoryWarningNotificationName, object: nil)
    }

    @objc private func clearMemory() {
        lineControllerStorage.removeAllLineControllers(exceptLinesWithID: visibleLineIDs)
    }
}
#endif
