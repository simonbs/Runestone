// swiftlint:disable file_length
import CoreText
import UIKit

protocol LayoutManagerDelegate: AnyObject {
    func layoutManager(_ layoutManager: LayoutManager, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint)
}

final class LayoutManager {
    weak var delegate: LayoutManagerDelegate?
    weak var gutterParentView: UIView? {
        didSet {
            if gutterParentView != oldValue {
                setupViewHierarchy()
            }
        }
    }
    weak var textInputView: UIView? {
        didSet {
            if textInputView != oldValue {
                setupViewHierarchy()
            }
        }
    }
    var lineManager: LineManager
    var stringView: StringView
    var scrollViewWidth: CGFloat = 0
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
    var theme: Theme = DefaultTheme.shared {
        didSet {
            if theme !== oldValue {
                applyTheme()
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
    var textContainerInset: UIEdgeInsets = .zero
    var safeAreaInsets: UIEdgeInsets = .zero
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
            return scrollViewWidth - leadingLineSpacing - textContainerInset.right - safeAreaInsets.left - safeAreaInsets.right
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
    /// Spelling decorations in document UTF-16 coordinates, independent of syntax and search highlights.
    var misspelledRanges: [NSRange] = [] {
        didSet {
            if misspelledRanges != oldValue {
                updateSpellingOnVisibleLines()
            }
        }
    }
    /// The text covered by the fragments from the most recent viewport layout.
    private(set) var visibleTextRange: NSRange?
    /// Individual visible ranges avoid including hidden columns between long unwrapped lines.
    private(set) var visibleTextRanges: [NSRange] = []

    // MARK: - Views
    let gutterContainerView = UIView()
    private var lineFragmentViewReuseQueue = ViewReuseQueue<LineFragmentID, LineFragmentView>()
    private var lineNumberLabelReuseQueue = ViewReuseQueue<DocumentLineNodeID, LineNumberView>()
    private var visibleLineIDs: Set<DocumentLineNodeID> = []
    private let linesContainerView = UIView()
    var writingToolsHiddenRanges: [NSRange] = [] {
        didSet { updateWritingToolsMask() }
    }

    private let gutterBackgroundView = GutterBackgroundView()
    private let lineNumbersContainerView = UIView()
    private let gutterSelectionBackgroundView = UIView()
    private let lineSelectionBackgroundView = UIView()

    // MARK: - Sizing
    private var leadingLineSpacing: CGFloat {
        if showLineNumbers {
            return gutterWidthService.gutterWidth + textContainerInset.left
        } else {
            return textContainerInset.left
        }
    }
    private var insetViewport: CGRect {
        let x = viewport.minX - textContainerInset.left
        let y = viewport.minY - textContainerInset.top
        let width = viewport.width + textContainerInset.left + textContainerInset.right
        let height = viewport.height + textContainerInset.top + textContainerInset.bottom
        return CGRect(x: x, y: y, width: width, height: height)
    }
    private let contentSizeService: ContentSizeService
    private let gutterWidthService: GutterWidthService
    private let caretRectService: CaretRectService
    private let selectionRectService: SelectionRectService
    private let highlightService: HighlightService

    // MARK: - Rendering
    private let invisibleCharacterConfiguration: InvisibleCharacterConfiguration
    private let lineControllerStorage: LineControllerStorage
    private var needsLayout = false
    private var needsSynchronousDestinationHighlight = false
    private var needsLayoutLineSelection = false

    init(lineManager: LineManager,
         languageMode: InternalLanguageMode,
         stringView: StringView,
         lineControllerStorage: LineControllerStorage,
         contentSizeService: ContentSizeService,
         gutterWidthService: GutterWidthService,
         caretRectService: CaretRectService,
         selectionRectService: SelectionRectService,
         highlightService: HighlightService,
         invisibleCharacterConfiguration: InvisibleCharacterConfiguration) {
        self.lineManager = lineManager
        self.languageMode = languageMode
        self.stringView = stringView
        self.invisibleCharacterConfiguration = invisibleCharacterConfiguration
        self.lineControllerStorage = lineControllerStorage
        self.contentSizeService = contentSizeService
        self.gutterWidthService = gutterWidthService
        self.caretRectService = caretRectService
        self.selectionRectService = selectionRectService
        self.highlightService = highlightService
        self.linesContainerView.isUserInteractionEnabled = false
        self.lineNumbersContainerView.isUserInteractionEnabled = false
        // Line numbers decorate the text; separate VoiceOver stops obscure the editor's controls.
        self.lineNumbersContainerView.accessibilityElementsHidden = true
        self.gutterContainerView.isUserInteractionEnabled = false
        self.gutterBackgroundView.isUserInteractionEnabled = false
        self.gutterSelectionBackgroundView.isUserInteractionEnabled = false
        self.lineSelectionBackgroundView.isUserInteractionEnabled = false
        // Initial theme assignments do not invoke didSet, and callers may reuse the same shared theme.
        self.applyTheme()
        self.updateShownViews()
        let memoryWarningNotificationName = UIApplication.didReceiveMemoryWarningNotification
        NotificationCenter.default.addObserver(self, selector: #selector(clearMemory), name: memoryWarningNotificationName, object: nil)
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

    func redisplayLines(withIDs lineIDs: Set<DocumentLineNodeID>) {
        for lineID in lineIDs {
            if let lineController = lineControllerStorage[lineID] {
                lineController.invalidateEverything()
                // Only display the line if it's currently visible on the screen. Otherwise it's enough to invalidate it and redisplay it later.
                if visibleLineIDs.contains(lineID) {
                    let lineYPosition = lineController.line.yPosition
                    let lineLocalViewport = CGRect(x: 0, y: 0, width: insetViewport.width, height: max(0, insetViewport.maxY - lineYPosition))
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
        return TextPreview(needleRange: needleRange,
                           previewRange: previewRange,
                           needleInPreviewRange: needleInPreviewRange,
                           lineControllers: lineControllers)
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

    func closestIndex(to point: CGPoint) -> Int? {
        let adjustedXPosition = point.x - leadingLineSpacing
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
            layoutLinesInViewport()
            layoutGutter()
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

    private func layoutGutter() {
        let totalGutterWidth = safeAreaInsets.left + gutterWidthService.gutterWidth
        let contentSize = contentSizeService.contentSize
        gutterContainerView.frame = CGRect(x: viewport.minX, y: 0, width: totalGutterWidth, height: contentSize.height)
        gutterBackgroundView.frame = CGRect(x: 0, y: viewport.minY, width: totalGutterWidth, height: viewport.height)
        lineNumbersContainerView.frame = CGRect(x: 0, y: 0, width: totalGutterWidth, height: contentSize.height)
    }

    private func layoutLineSelection() {
        if let rect = getLineSelectionRect() {
            let totalGutterWidth = safeAreaInsets.left + gutterWidthService.gutterWidth
            gutterSelectionBackgroundView.frame = CGRect(x: 0, y: rect.minY, width: totalGutterWidth, height: rect.height)
            let lineSelectionBackgroundOrigin = CGPoint(x: viewport.minX + totalGutterWidth, y: rect.minY)
            let lineSelectionBackgroundSize = CGSize(width: scrollViewWidth - gutterWidthService.gutterWidth, height: rect.height)
            lineSelectionBackgroundView.frame = CGRect(origin: lineSelectionBackgroundOrigin, size: lineSelectionBackgroundSize)
        }
    }

    private func getLineSelectionRect() -> CGRect? {
        guard lineSelectionDisplayType.shouldShowLineSelection, var selectedRange = selectedRange else {
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
            return CGRect(x: 0, y: textContainerInset.top + minY, width: scrollViewWidth, height: height)
        case .lineFragment:
            let startCaretRect = caretRectService.caretRect(at: selectedRange.lowerBound, allowMovingCaretToNextLineFragment: false)
            let endCaretRect = caretRectService.caretRect(at: selectedRange.upperBound, allowMovingCaretToNextLineFragment: false)
            let startLineFragmentHeight = startCaretRect.height * lineHeightMultiplier
            let endLineFragmentHeight = endCaretRect.height * lineHeightMultiplier
            let minY = startCaretRect.minY - (startLineFragmentHeight - startCaretRect.height) / 2
            let maxY = endCaretRect.maxY + (endLineFragmentHeight - endCaretRect.height) / 2
            return CGRect(x: 0, y: minY, width: scrollViewWidth, height: maxY - minY)
        case .disabled:
            return nil
        }
    }

    /// Prepare a destination without measuring the document prefix. Heights outside the
    /// destination's neighborhood remain estimates in the line tree.
    func layoutLines(toLocation location: Int) {
        guard constrainingLineWidth > 0,
              let line = lineManager.line(containingCharacterAt: min(max(0, location), stringView.string.length)) else {
            return
        }
        needsSynchronousDestinationHighlight = true
        let controller = lineControllerStorage.getOrCreateLineController(for: line)
        controller.constrainingWidth = constrainingLineWidth
        let localLocation = min(line.data.length, max(0, location - line.location))
        controller.prepareToDisplayString(toLocation: localLocation, syntaxHighlightAsynchronously: false)
        contentSizeService.setSize(of: line, to: CGSize(width: controller.lineWidth, height: controller.lineHeight))
        let destinationY = controller.caretRect(atIndex: localLocation).minY
        prepareLines(before: line, covering: max(0, viewport.height * 1.5 - destinationY),
                     syntaxHighlightAsynchronously: false)
        // Synchronous styling can replace already-visible fragments even when
        // revealing this destination leaves the scroll offset unchanged.
        setNeedsLayout()
    }

    /// Measure backwards from a known line so that discovering wrapped predecessors
    /// cannot displace it. Stop using measured heights, not the initial estimates.
    private func prepareLines(before anchor: DocumentLineNode, covering distance: CGFloat,
                              syntaxHighlightAsynchronously: Bool = true) {
        var remaining = distance
        var row = anchor.index - 1
        while row >= 0 && remaining > 0 {
            let line = lineManager.line(atRow: row)
            let controller = lineControllerStorage.getOrCreateLineController(for: line)
            controller.constrainingWidth = constrainingLineWidth
            controller.prepareToDisplayString(toLocation: line.data.length, syntaxHighlightAsynchronously: syntaxHighlightAsynchronously)
            contentSizeService.setSize(of: line, to: CGSize(width: controller.lineWidth, height: controller.lineHeight))
            remaining -= line.data.lineHeight
            row -= 1
        }
    }

    /// Prefer text already on screen when scrolling into an unmeasured region above it.
    /// A disjoint jump instead starts with the line at the new viewport position.
    private func viewportAnchor() -> DocumentLineNode? {
        let overlappingLines = visibleLineIDs.compactMap { lineControllerStorage[$0]?.line }.filter { line in
            line.yPosition + line.data.lineHeight > insetViewport.minY && line.yPosition < insetViewport.maxY
        }
        return overlappingLines.min { $0.yPosition < $1.yPosition }
            ?? lineManager.line(containingYOffset: max(0, insetViewport.minY))
    }

    // swiftlint:disable:next function_body_length
    private func layoutLinesInViewport() {
        // Immediately bail out from generating lines in a viewport of zero size.
        guard viewport.size.width > 0 && viewport.size.height > 0 else {
            visibleTextRange = nil
            visibleTextRanges = []
            return
        }
        let highlightDestinationSynchronously = needsSynchronousDestinationHighlight
        needsSynchronousDestinationHighlight = false
        var contentOffsetAdjustmentY: CGFloat = 0
        if constrainingLineWidth > 0, let anchor = viewportAnchor() {
            let oldAnchorY = anchor.yPosition
            let distance = max(0, oldAnchorY - insetViewport.minY + viewport.height * 0.5)
            prepareLines(before: anchor, covering: distance,
                         syntaxHighlightAsynchronously: !highlightDestinationSynchronously)
            contentOffsetAdjustmentY = anchor.yPosition - oldAnchorY
            // Render against the corrected viewport in this same transaction.
            viewport.origin.y += contentOffsetAdjustmentY
        }
        let oldVisibleLineIDs = visibleLineIDs
        let oldVisibleLineFragmentIDs = Set(lineFragmentViewReuseQueue.visibleViews.keys)
        // Layout lines until we have filled the viewport.
        var nextLine = lineManager.line(containingYOffset: insetViewport.minY)
        var appearedLineIDs: Set<DocumentLineNodeID> = []
        var appearedLineFragmentIDs: Set<LineFragmentID> = []
        var visibleRange: NSRange?
        var visibleRanges: [NSRange] = []
        var maxY = insetViewport.minY
        while let line = nextLine, maxY < insetViewport.maxY, constrainingLineWidth > 0 {
            appearedLineIDs.insert(line.id)
            // Prepare to line controller to display text.
            let lineLocalViewport = CGRect(x: 0, y: 0, width: insetViewport.width,
                                           height: max(0, insetViewport.maxY - line.yPosition))
            let lineController = lineControllerStorage.getOrCreateLineController(for: line)
            lineController.constrainingWidth = constrainingLineWidth
            // A newly revealed destination should appear with its final colors on
            // the first frame. Ordinary scrolling keeps asynchronous highlighting.
            lineController.prepareToDisplayString(in: lineLocalViewport,
                                                  syntaxHighlightAsynchronously: !highlightDestinationSynchronously)
            let lineSize = CGSize(width: lineController.lineWidth, height: lineController.lineHeight)
            contentSizeService.setSize(of: line, to: lineSize)
            // A jump into the estimated tail of a partially measured line may finish
            // it above the viewport. There is no real text at that estimated position:
            // relocate to its actual tail before displaying any frames.
            if appearedLineIDs.count == 1 && lineController.isFinishedTypesetting
                && line.yPosition + lineSize.height <= insetViewport.minY {
                let correctedTop = max(line.yPosition, line.yPosition + lineSize.height - viewport.height)
                let adjustment = correctedTop - insetViewport.minY
                viewport.origin.y += adjustment
                contentOffsetAdjustmentY += adjustment
            }
            layoutLineNumberView(for: line)
            // Layout line fragments ("sublines") in the line until we have filled the viewport.
            let lineYPosition = line.yPosition
            let lineFragmentControllers = lineController.lineFragmentControllers(in: insetViewport)
            for lineFragmentController in lineFragmentControllers {
                let lineFragment = lineFragmentController.lineFragment
                var lineFragmentFrame: CGRect = .zero
                appearedLineFragmentIDs.insert(lineFragment.id)
                for localRange in visibleCharacterRanges(in: lineFragmentController) {
                    let documentRange = NSRange(location: line.location + localRange.location, length: localRange.length)
                    visibleRange = visibleRange.map { NSUnionRange($0, documentRange) } ?? documentRange
                    visibleRanges.append(documentRange)
                }
                updateSpelling(on: lineFragmentController, lineLocation: line.location)
                lineFragmentController.highlightedRangeFragments = highlightService.highlightedRangeFragments(for: lineFragment,
                                                                                                              inLineWithID: line.id)
                layoutLineFragmentView(for: lineFragmentController,
                                       lineLocation: line.location,
                                       lineYPosition: lineYPosition,
                                       lineFragmentFrame: &lineFragmentFrame)
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
            if !stoppedGeneratingLineFragments && line.index < lineManager.lineCount - 1 {
                nextLine = lineManager.line(atRow: line.index + 1)
            } else {
                nextLine = nil
            }
        }
        let contentSize = contentSizeService.contentSize
        linesContainerView.frame = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
        // Update the visible lines and line fragments. Clean up everything that is not in the viewport anymore.
        visibleLineIDs = appearedLineIDs
        visibleTextRange = visibleRange
        visibleTextRanges = visibleRanges
        let disappearedLineIDs = oldVisibleLineIDs.subtracting(appearedLineIDs)
        let disappearedLineFragmentIDs = oldVisibleLineFragmentIDs.subtracting(appearedLineFragmentIDs)
        for disappearedLineID in disappearedLineIDs {
            let lineController = lineControllerStorage[disappearedLineID]
            lineController?.cancelSyntaxHighlighting()
        }
        lineNumberLabelReuseQueue.enqueueViews(withKeys: disappearedLineIDs)
        lineFragmentViewReuseQueue.enqueueViews(withKeys: disappearedLineFragmentIDs)
        updateWritingToolsMask()
        // Adjust the content offset on the Y-axis if necessary.
        if contentOffsetAdjustmentY != 0 {
            let contentOffsetAdjustment = CGPoint(x: 0, y: contentOffsetAdjustmentY)
            delegate?.layoutManager(self, didProposeContentOffsetAdjustment: contentOffsetAdjustment)
        }
    }

    private func layoutLineNumberView(for line: DocumentLineNode) {
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

    private func layoutLineFragmentView(for lineFragmentController: LineFragmentController,
                                        lineLocation: Int,
                                        lineYPosition: CGFloat,
                                        lineFragmentFrame: inout CGRect) {
        let lineFragment = lineFragmentController.lineFragment
        let lineFragmentView = lineFragmentViewReuseQueue.dequeueView(forKey: lineFragment.id)
        if lineFragmentView.superview == nil {
            linesContainerView.addSubview(lineFragmentView)
        }
        lineFragmentView.documentLineLocation = lineLocation
        lineFragmentController.lineFragmentView = lineFragmentView
        let lineFragmentOrigin = CGPoint(x: leadingLineSpacing, y: textContainerInset.top + lineYPosition + lineFragment.yPosition)
        let lineFragmentWidth = contentSizeService.contentWidth - leadingLineSpacing - textContainerInset.right
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
        gutterContainerView.removeFromSuperview()
        gutterBackgroundView.removeFromSuperview()
        gutterSelectionBackgroundView.removeFromSuperview()
        lineNumbersContainerView.removeFromSuperview()
        let allLineNumberKeys = lineFragmentViewReuseQueue.visibleViews.keys
        lineFragmentViewReuseQueue.enqueueViews(withKeys: Set(allLineNumberKeys))
        // Add views to view hierarchy
        textInputView?.addSubview(lineSelectionBackgroundView)
        textInputView?.addSubview(linesContainerView)
        gutterParentView?.addSubview(gutterContainerView)
        gutterContainerView.addSubview(gutterBackgroundView)
        gutterContainerView.addSubview(gutterSelectionBackgroundView)
        gutterContainerView.addSubview(lineNumbersContainerView)
    }

    private func applyTheme() {
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
    }

    private func updateShownViews() {
        let selectedLength = selectedRange?.length ?? 0
        gutterBackgroundView.isHidden = !showLineNumbers
        lineNumbersContainerView.isHidden = !showLineNumbers
        gutterSelectionBackgroundView.isHidden = !lineSelectionDisplayType.shouldShowLineSelection || !showLineNumbers || !isEditing
        lineSelectionBackgroundView.isHidden = !lineSelectionDisplayType.shouldShowLineSelection || !isEditing || selectedLength > 0
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

// MARK: - Spelling geometry
extension LayoutManager {
    /// Visible word rectangles in text input coordinates, split at wrapping and bidirectional run boundaries.
    func spellingRects(for range: NSRange) -> [CGRect] {
        guard range.location >= 0, range.location <= stringView.string.length,
              range.length > 0, range.length <= stringView.string.length - range.location else {
            return []
        }
        let gutterWidth = showLineNumbers ? safeAreaInsets.left + gutterWidthService.gutterWidth : 0
        let visibleTextRect = CGRect(x: viewport.minX + gutterWidth, y: viewport.minY,
                                     width: max(0, viewport.width - gutterWidth), height: viewport.height)
        return lineFragmentViewReuseQueue.visibleViews.values.flatMap { view -> [CGRect] in
            guard let renderer = view.renderer else {
                return []
            }
            let fragmentRange = renderer.lineFragment.visibleRange
            let documentRange = NSRange(location: view.documentLineLocation + fragmentRange.location, length: fragmentRange.length)
            let intersection = NSIntersectionRange(documentRange, range)
            guard intersection.length > 0 else {
                return []
            }
            let localRange = NSRange(location: intersection.location - view.documentLineLocation, length: intersection.length)
            return renderer.spellingUnderlineSegments(in: localRange).compactMap { segment in
                // Fragment frames already include the document line origin, gutter, and text-container insets.
                let rect = CGRect(x: view.frame.minX + segment.lowerBound, y: view.frame.minY,
                                  width: segment.upperBound - segment.lowerBound, height: view.frame.height)
                    .intersection(visibleTextRect)
                return rect.isNull || rect.isEmpty ? nil : rect
            }
        }.sorted { $0.minY == $1.minY ? $0.minX < $1.minX : $0.minY < $1.minY }
    }
}

// MARK: - Spelling
private extension LayoutManager {
    private func visibleCharacterRanges(in controller: LineFragmentController) -> [NSRange] {
        if isLineWrappingEnabled {
            return [controller.lineFragment.visibleRange]
        }
        // Include partially visible glyphs and a small margin; the spelling service expands to word boundaries.
        let lowerBound = viewport.minX - leadingLineSpacing - 32
        let upperBound = viewport.maxX - leadingLineSpacing + 32
        return controller.visibleCharacterRanges(in: lowerBound ... upperBound)
    }

    private func updateSpellingOnVisibleLines() {
        for lineID in visibleLineIDs {
            guard let lineController = lineControllerStorage[lineID] else {
                continue
            }
            for fragmentController in lineController.lineFragmentControllers(in: insetViewport) {
                updateSpelling(on: fragmentController, lineLocation: lineController.line.location)
            }
        }
    }

    private func updateSpelling(on controller: LineFragmentController, lineLocation: Int) {
        let fragmentRange = controller.lineFragment.visibleRange
        let documentRange = NSRange(location: lineLocation + fragmentRange.location, length: fragmentRange.length)
        controller.misspelledRanges = misspelledRanges.compactMap { range in
            let intersection = NSIntersectionRange(range, documentRange)
            guard intersection.length > 0 else {
                return nil
            }
            return NSRange(location: intersection.location - lineLocation, length: intersection.length)
        }
    }
}

// MARK: - Memory Management
private extension LayoutManager {
    @objc private func clearMemory() {
        lineControllerStorage.removeAllLineControllers(exceptLinesWithID: visibleLineIDs)
    }
}

// MARK: - Writing Tools rendering
extension LayoutManager {
    /// One rectangle per visible typeset line, in the text input view's coordinates.
    func writingToolsTextRects(in range: NSRange) -> [CGRect] {
        lineFragmentViewReuseQueue.visibleViews.values.compactMap { view in
            guard let fragment = view.renderer?.lineFragment else {
                return nil
            }
            let documentRange = NSRange(location: view.documentLineLocation + fragment.visibleRange.location,
                                        length: fragment.visibleRange.length)
            let intersection = NSIntersectionRange(documentRange, range)
            guard intersection.length > 0 else {
                return nil
            }
            let start = intersection.location - view.documentLineLocation
            let end = NSMaxRange(intersection) - view.documentLineLocation
            let firstX = CTLineGetOffsetForStringIndex(fragment.line, start, nil)
            let lastX = CTLineGetOffsetForStringIndex(fragment.line, end, nil)
            let rect = CGRect(x: view.frame.minX + min(firstX, lastX), y: view.frame.minY,
                              width: abs(lastX - firstX), height: view.frame.height)
            return rect.width > 0 ? rect : nil
        }.sorted { $0.minY == $1.minY ? $0.minX < $1.minX : $0.minY < $1.minY }
    }

    func drawWritingToolsText(in context: CGContext) {
        for view in lineFragmentViewReuseQueue.visibleViews.values {
            context.saveGState()
            context.translateBy(x: view.frame.minX, y: view.frame.minY)
            view.renderer?.drawText(to: context)
            context.restoreGState()
        }
    }

    private func updateWritingToolsMask() {
        guard !writingToolsHiddenRanges.isEmpty else {
            linesContainerView.layer.mask = nil
            return
        }
        let scale = textInputView?.window?.screen.scale ?? UIScreen.main.scale
        var path = CGPath(rect: linesContainerView.bounds, transform: nil)
        for range in writingToolsHiddenRanges {
            for rect in writingToolsTextRects(in: range) {
                // Match the display resolution and cover fractional edge pixels without
                // expanding into the neighboring glyphs by an arbitrary point-sized margin.
                let pixelRect = CGRect(x: floor(rect.minX * scale),
                                       y: floor(rect.minY * scale),
                                       width: ceil(rect.maxX * scale) - floor(rect.minX * scale),
                                       height: ceil(rect.maxY * scale) - floor(rect.minY * scale))
                let hiddenRect = CGRect(x: pixelRect.minX / scale, y: pixelRect.minY / scale,
                                        width: pixelRect.width / scale, height: pixelRect.height / scale)
                if #available(iOS 16.0, *) {
                    // Subtraction keeps overlapping pixel-aligned line rectangles hidden as well.
                    path = path.subtracting(CGPath(rect: hiddenRect, transform: nil))
                }
            }
        }
        let mask = CAShapeLayer()
        mask.contentsScale = scale
        mask.frame = linesContainerView.bounds
        mask.path = path
        linesContainerView.layer.mask = mask
    }
}
