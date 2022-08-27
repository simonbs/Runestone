// swiftlint:disable file_length

import UIKit

protocol LayoutManagerDelegate: AnyObject {
    func layoutManagerDidInvalidateContentSize(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint)
    func layoutManagerDidChangeGutterWidth(_ layoutManager: LayoutManager)
}

// swiftlint:disable:next type_body_length
final class LayoutManager {
    weak var delegate: LayoutManagerDelegate?
    weak var scrollView: UIScrollView? {
        didSet {
            if scrollView != oldValue {
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
    var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                shouldResetLineWidths = true
            }
        }
    }
    var stringView: StringView
    var scrollViewWidth: CGFloat = 0 {
        didSet {
            if scrollViewWidth != oldValue && isLineWrappingEnabled {
                invalidateContentSize()
            }
        }
    }
    var viewport: CGRect = .zero
    var contentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }
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
                updateLineNumberWidth()
                if theme.font != oldValue.font {
                    invalidateContentSize()
                }
                // Clear the cached highlight rects as the font size might have changed, causing the position of the highlights to change.
                highlightRectsForLineIDs = [:]
                clearHighlightedViews()
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
                if showLineNumbers {
                    updateLineNumberWidth()
                }
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
    var invisibleCharacterConfiguration = InvisibleCharacterConfiguration()
    var isLineWrappingEnabled = true {
        didSet {
            if isLineWrappingEnabled != oldValue {
                invalidateContentSize()
            }
        }
    }
    /// Leading padding inside the gutter.
    var gutterLeadingPadding: CGFloat = 3 {
        didSet {
            if gutterLeadingPadding != oldValue {
                invalidateContentSize()
            }
        }
    }
    /// Trailing padding inside the gutter.
    var gutterTrailingPadding: CGFloat = 3 {
        didSet {
            if gutterTrailingPadding != oldValue {
                invalidateContentSize()
            }
        }
    }
    /// Spacing around the text. The left-side spacing defines the distance between the text and the gutter.
    var textContainerInset: UIEdgeInsets = .zero {
        didSet {
            if textContainerInset != oldValue {
                invalidateContentSize()
            }
        }
    }
    var selectedRange: NSRange? {
        didSet {
            if selectedRange != oldValue {
                updateShownViews()
            }
        }
    }
    /// Total width of the gutter containing the line numbers.
    var gutterWidth: CGFloat {
        if showLineNumbers {
            return lineNumberWidth + gutterLeadingPadding + gutterTrailingPadding
        } else {
            return 0
        }
    }
    var lineHeightMultiplier: CGFloat = 1 {
        didSet {
            if lineHeightMultiplier != oldValue {
                invalidateContentSize()
            }
        }
    }
    var constrainingLineWidth: CGFloat {
        if isLineWrappingEnabled {
            return scrollViewWidth - leadingLineSpacing - textContainerInset.right - safeAreaInset.left - safeAreaInset.right
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
    var highlightedRanges: [HighlightedRange] = [] {
        didSet {
            if highlightedRanges != oldValue {
                highlightRectsForLineIDs = [:]
                clearHighlightedViews()
                recreateHighlightedRangesMap()
                setNeedsLayout()
                layoutIfNeeded()
            }
        }
    }
    private var highlightedRangesMap: [DocumentLineNodeID: [HighlightedRange]] = [:]

    // MARK: - Views
    let gutterContainerView = UIView()
    private var lineFragmentViewReuseQueue = ViewReuseQueue<LineFragmentID, LineFragmentView>()
    private var lineNumberLabelReuseQueue = ViewReuseQueue<DocumentLineNodeID, LineNumberView>()
    private var highlightViewReuseQueue = ViewReuseQueue<String, HighlightView>()
    private var highlightRectsForLineIDs: [DocumentLineNodeID: [CachedHighlightRect]] = [:]
    private var visibleLineIDs: Set<DocumentLineNodeID> = []
    private let linesContainerView = UIView()
    private let gutterBackgroundView = GutterBackgroundView()
    private let lineNumbersContainerView = UIView()
    private let gutterSelectionBackgroundView = UIView()
    private let lineSelectionBackgroundView = UIView()
    private let highlightsContainerBackgroundView = UIView()

    // MARK: - Sizing
    private var contentWidth: CGFloat {
        if isLineWrappingEnabled {
            return scrollViewWidth - safeAreaInset.left - safeAreaInset.right
        } else {
            return ceil(textContentWidth + leadingLineSpacing + textContainerInset.right + maximumLineBreakSymbolWidth)
        }
    }
    private var contentHeight: CGFloat {
        return ceil(textContentHeight + textContainerInset.top + textContainerInset.bottom)
    }
    private var textContentWidth: CGFloat {
        if let textContentWidth = _textContentWidth {
            return textContentWidth
        } else if let lineIDTrackingWidth = lineIDTrackingWidth, let lineWidth = lineWidths[lineIDTrackingWidth] {
            let textContentWidth = lineWidth
            _textContentWidth = textContentWidth
            return textContentWidth
        } else {
            lineIDTrackingWidth = nil
            var maximumWidth: CGFloat?
            for (lineID, lineWidth) in lineWidths {
                if let _maximumWidth = maximumWidth {
                    if lineWidth > _maximumWidth {
                        lineIDTrackingWidth = lineID
                        maximumWidth = lineWidth
                    }
                } else {
                    lineIDTrackingWidth = lineID
                    maximumWidth = lineWidth
                }
            }
            let textContentWidth = maximumWidth ?? scrollViewWidth
            _textContentWidth = textContentWidth
            return textContentWidth
        }
    }
    private var textContentHeight: CGFloat {
        if let contentHeight = _textContentHeight {
            return contentHeight
        } else {
            let contentHeight = lineManager.contentHeight
            _textContentHeight = contentHeight
            return contentHeight
        }
    }
    private var _textContentWidth: CGFloat?
    private var _textContentHeight: CGFloat?
    private var lineNumberWidth: CGFloat = 0
    private var previousLineNumberWidthUpdateLineCount: Int?
    private var previousLineNumberWidthUpdateFont: UIFont?
    /// Spacing in front of a line.
    private var leadingLineSpacing: CGFloat {
        if showLineNumbers {
            return gutterWidth + textContainerInset.left
        } else {
            return textContainerInset.left
        }
    }
    // Reset the line widths when changing the line manager to measure the longest line and use it to determine the content width.
    private var shouldResetLineWidths = true
    private var lineWidths: [DocumentLineNodeID: CGFloat] = [:]
    private var lineIDTrackingWidth: DocumentLineNodeID?
    private var insetViewport: CGRect {
        let x = viewport.minX - textContainerInset.left
        let y = viewport.minY - textContainerInset.top
        let width = viewport.width + textContainerInset.left + textContainerInset.right
        let height = viewport.height + textContainerInset.top + textContainerInset.bottom
        return CGRect(x: x, y: y, width: width, height: height)
    }
    private var safeAreaInset: UIEdgeInsets {
        let adjustContentInset = scrollView?.adjustedContentInset ?? .zero
        let contentInset = scrollView?.contentInset ?? .zero
        let topInset = adjustContentInset.top - contentInset.top
        let leftInset = adjustContentInset.left - contentInset.left
        let bottomInset = adjustContentInset.bottom - contentInset.bottom
        let rightInset = adjustContentInset.right - contentInset.right
        return UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
    }

    // MARK: - Rendering
    private let lineControllerStorage: LineControllerStorage
    private var needsLayout = false
    private var needsLayoutLineSelection = false
    private var maximumLineBreakSymbolWidth: CGFloat {
        if invisibleCharacterConfiguration.showLineBreaks && invisibleCharacterConfiguration.showSoftLineBreaks {
            return max(invisibleCharacterConfiguration.lineBreakSymbolSize.width, invisibleCharacterConfiguration.softLineBreakSymbolSize.width)
        } else if invisibleCharacterConfiguration.showLineBreaks {
            return invisibleCharacterConfiguration.lineBreakSymbolSize.width
        } else if invisibleCharacterConfiguration.showSoftLineBreaks {
            return invisibleCharacterConfiguration.softLineBreakSymbolSize.width
        } else {
            return 0
        }
    }

    init(lineManager: LineManager, languageMode: InternalLanguageMode, stringView: StringView, lineControllerStorage: LineControllerStorage) {
        self.lineManager = lineManager
        self.languageMode = languageMode
        self.stringView = stringView
        self.lineControllerStorage = lineControllerStorage
        self.linesContainerView.isUserInteractionEnabled = false
        self.lineNumbersContainerView.isUserInteractionEnabled = false
        self.gutterContainerView.isUserInteractionEnabled = false
        self.gutterBackgroundView.isUserInteractionEnabled = false
        self.gutterSelectionBackgroundView.isUserInteractionEnabled = false
        self.lineSelectionBackgroundView.isUserInteractionEnabled = false
        self.highlightsContainerBackgroundView.isUserInteractionEnabled = false
        self.updateShownViews()
        let memoryWarningNotificationName = UIApplication.didReceiveMemoryWarningNotification
        NotificationCenter.default.addObserver(self, selector: #selector(clearMemory), name: memoryWarningNotificationName, object: nil)
    }

    func invalidateContentSize() {
        _textContentWidth = nil
        _textContentHeight = nil
    }

    func removeLine(withID lineID: DocumentLineNodeID) {
        lineWidths.removeValue(forKey: lineID)
        lineControllerStorage.removeLineController(withID: lineID)
        if lineID == lineIDTrackingWidth {
            lineIDTrackingWidth = nil
            _textContentWidth = nil
            delegate?.layoutManagerDidInvalidateContentSize(self)
        }
    }

    func updateLineNumberWidth() {
        guard showLineNumbers else {
            return
        }
        let lineCount = lineManager.lineCount
        let hasLineCountChanged = lineCount != previousLineNumberWidthUpdateLineCount
        let hasFontChanged = theme.lineNumberFont != previousLineNumberWidthUpdateFont
        if hasLineCountChanged || hasFontChanged {
            previousLineNumberWidthUpdateLineCount = lineCount
            previousLineNumberWidthUpdateFont = theme.lineNumberFont
            let characterCount = "\(lineCount)".count
            let wideLineNumberString = String(repeating: "8", count: characterCount)
            let wideLineNumberNSString = wideLineNumberString as NSString
            let size = wideLineNumberNSString.size(withAttributes: [.font: theme.lineNumberFont])
            let oldLineNumberWidth = lineNumberWidth
            lineNumberWidth = ceil(size.width) + gutterLeadingPadding + gutterTrailingPadding
            if lineNumberWidth != oldLineNumberWidth {
                delegate?.layoutManagerDidChangeGutterWidth(self)
                _textContentWidth = nil
                delegate?.layoutManagerDidInvalidateContentSize(self)
            }
        }
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
        return TextPreview(needleRange: needleRange,
                           previewRange: previewRange,
                           needleInPreviewRange: needleInPreviewRange,
                           lineControllers: lineControllers)
    }
}

// MARK: - UITextInput
extension LayoutManager {
    func caretRect(at location: Int) -> CGRect {
        let safeLocation = min(max(location, 0), stringView.string.length)
        let line = lineManager.line(containingCharacterAt: safeLocation)!
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let localLocation = safeLocation - line.location
        let localCaretRect = lineController.caretRect(atIndex: localLocation)
        let globalYPosition = line.yPosition + localCaretRect.minY
        let globalRect = CGRect(x: localCaretRect.minX, y: globalYPosition, width: localCaretRect.width, height: localCaretRect.height)
        return globalRect.offsetBy(dx: leadingLineSpacing, dy: textContainerInset.top)
    }

    func firstRect(for range: NSRange) -> CGRect {
        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let localRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
        let lineContentsRect = lineController.firstRect(for: localRange)
        let visibleWidth = viewport.width - gutterWidth
        let xPosition = lineContentsRect.minX + textContainerInset.left + gutterWidth
        let yPosition = line.yPosition + lineContentsRect.minY + textContainerInset.top
        let width = min(lineContentsRect.width, visibleWidth)
        return CGRect(x: xPosition, y: yPosition, width: width, height: lineContentsRect.height)
    }

    func selectionRects(in range: NSRange) -> [TextSelectionRect] {
        guard range.length > 0 else {
            return []
        }
        guard let endLine = lineManager.line(containingCharacterAt: range.upperBound) else {
            return []
        }
        let selectsLineEnding = range.upperBound == endLine.location
        let adjustedRange = NSRange(location: range.location, length: selectsLineEnding ? range.length - 1 : range.length)
        let startCaretRect = caretRect(at: adjustedRange.lowerBound)
        let endCaretRect = caretRect(at: adjustedRange.upperBound)
        let fullWidth = max(contentWidth, scrollViewWidth) - textContainerInset.right
        if startCaretRect.minY == endCaretRect.minY && startCaretRect.maxY == endCaretRect.maxY {
            // Selecting text in the same line fragment.
            let width = selectsLineEnding ? fullWidth - leadingLineSpacing : endCaretRect.maxX - startCaretRect.maxX
            let scaledHeight = startCaretRect.height * lineHeightMultiplier
            let offsetY = startCaretRect.minY - (scaledHeight - startCaretRect.height) / 2
            let rect = CGRect(x: startCaretRect.minX, y: offsetY, width: width, height: scaledHeight)
            let selectionRect = TextSelectionRect(rect: rect, writingDirection: .natural, containsStart: true, containsEnd: true)
            return [selectionRect]
        } else {
            // Selecting text across line fragments and possibly across lines.
            let startWidth = fullWidth - startCaretRect.minX
            let startScaledHeight = startCaretRect.height * lineHeightMultiplier
            let startOffsetY = startCaretRect.minY - (startScaledHeight - startCaretRect.height) / 2
            let startRect = CGRect(x: startCaretRect.minX, y: startOffsetY, width: startWidth, height: startScaledHeight)
            let endWidth = selectsLineEnding ? fullWidth - leadingLineSpacing : endCaretRect.minX - leadingLineSpacing
            let endScaledHeight = endCaretRect.height * lineHeightMultiplier
            let endOffsetY = endCaretRect.minY - (endScaledHeight - endCaretRect.height) / 2
            let endRect = CGRect(x: leadingLineSpacing, y: endOffsetY, width: endWidth, height: endScaledHeight)
            let middleWidth = fullWidth - leadingLineSpacing
            let middleHeight = endRect.minY - startRect.maxY
            let middleRect = CGRect(x: leadingLineSpacing, y: startRect.maxY, width: middleWidth, height: middleHeight)
            let startSelectionRect = TextSelectionRect(rect: startRect, writingDirection: .natural, containsStart: true, containsEnd: false)
            let middleSelectionRect = TextSelectionRect(rect: middleRect, writingDirection: .natural, containsStart: false, containsEnd: false)
            let endSelectionRect = TextSelectionRect(rect: endRect, writingDirection: .natural, containsStart: false, containsEnd: true)
            return [startSelectionRect, middleSelectionRect, endSelectionRect]
        }
    }

    func closestIndex(to point: CGPoint) -> Int? {
        let adjustedXPosition = point.x - leadingLineSpacing
        let adjustedYPosition = point.y - textContainerInset.top
        let adjustedPoint = CGPoint(x: adjustedXPosition, y: adjustedYPosition)
        if let line = lineManager.line(containingYOffset: adjustedPoint.y), let lineController = lineControllerStorage[line.id] {
            return closestIndex(to: adjustedPoint, in: lineController, showing: line)
        } else if adjustedPoint.y <= 0 {
            let firstLine = lineManager.firstLine
            if let textRenderer = lineControllerStorage[firstLine.id] {
                return closestIndex(to: adjustedPoint, in: textRenderer, showing: firstLine)
            } else {
                return 0
            }
        } else {
            let lastLine = lineManager.lastLine
            if adjustedPoint.y >= lastLine.yPosition, let textRenderer = lineControllerStorage[lastLine.id] {
                return closestIndex(to: adjustedPoint, in: textRenderer, showing: lastLine)
            } else {
                return stringView.string.length
            }
        }
    }

    private func closestIndex(to point: CGPoint, in lineController: LineController, showing line: DocumentLineNode) -> Int {
        let localPoint = CGPoint(x: point.x, y: point.y - line.yPosition)
        let index = lineController.closestIndex(to: localPoint)
        if index >= line.data.length && index <= line.data.totalLength && line != lineManager.lastLine {
            return line.location + line.data.length
        } else {
            return line.location + index
        }
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
            resetLineWidthsIfNecessary()
            layoutGutter()
            layoutLineSelection()
            layoutLinesInViewport()
            updateLineNumberColors()
            highlightsContainerBackgroundView.frame = textInputView?.frame ?? .zero
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
        let totalGutterWidth = safeAreaInset.left + gutterWidth
        gutterContainerView.frame = CGRect(x: viewport.minX, y: 0, width: totalGutterWidth, height: contentSize.height)
        gutterBackgroundView.frame = CGRect(x: 0, y: viewport.minY, width: totalGutterWidth, height: viewport.height)
        lineNumbersContainerView.frame = CGRect(x: 0, y: 0, width: totalGutterWidth, height: contentSize.height)
    }

    private func layoutLineSelection() {
        if let rect = getLineSelectionRect() {
            let totalGutterWidth = safeAreaInset.left + gutterWidth
            gutterSelectionBackgroundView.frame = CGRect(x: 0, y: rect.minY, width: totalGutterWidth, height: rect.height)
            let lineSelectionBackgroundOrigin = CGPoint(x: viewport.minX + totalGutterWidth, y: rect.minY)
            let lineSelectionBackgroundSize = CGSize(width: scrollViewWidth - gutterWidth, height: rect.height)
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
            let startCaretRect = caretRect(at: selectedRange.lowerBound)
            let endCaretRect = caretRect(at: selectedRange.upperBound)
            let startLineFragmentHeight = startCaretRect.height * lineHeightMultiplier
            let endLineFragmentHeight = endCaretRect.height * lineHeightMultiplier
            let minY = startCaretRect.minY - (startLineFragmentHeight - startCaretRect.height) / 2
            let maxY = endCaretRect.maxY + (endLineFragmentHeight - endCaretRect.height) / 2
            return CGRect(x: 0, y: minY, width: scrollViewWidth, height: maxY - minY)
        case .disabled:
            return nil
        }
    }

    func layoutLines(toLocation location: Int) {
        var nextLine: DocumentLineNode? = lineManager.firstLine
        let isLocationEndOfString = location >= stringView.string.length
        while let line = nextLine {
            let lineLocation = line.location
            let endTypesettingLocation = min(lineLocation + line.data.length, location) - lineLocation
            let lineController = lineControllerStorage.getOrCreateLineController(for: line)
            lineController.constrainingWidth = constrainingLineWidth
            lineController.prepareToDisplayString(toLocation: endTypesettingLocation, syntaxHighlightAsynchronously: true)
            let lineSize = CGSize(width: lineController.lineWidth, height: lineController.lineHeight)
            setSize(of: lineController.line, to: lineSize)
            let lineEndLocation = lineLocation + line.data.length
            if (lineEndLocation < location) || (lineLocation == location && !isLocationEndOfString) {
                nextLine = lineManager.line(atRow: line.index + 1)
            } else {
                nextLine = nil
            }
        }
        if _textContentHeight == nil || _textContentWidth == nil {
            delegate?.layoutManagerDidInvalidateContentSize(self)
        }
    }

    // swiftlint:disable:next function_body_length
    private func layoutLinesInViewport() {
        // Immediately bail out from generating lines in a viewport of zero size.
        guard viewport.size.width > 0 && viewport.size.height > 0 else {
            return
        }
        let oldTextContentWidth = _textContentWidth
        let oldTextContentHeight = _textContentHeight
        let oldVisibleLineIDs = visibleLineIDs
        let oldVisibleLineFragmentIDs = Set(lineFragmentViewReuseQueue.visibleViews.keys)
        // Layout lines until we have filled the viewport.
        var nextLine = lineManager.line(containingYOffset: insetViewport.minY)
        var appearedLineIDs: Set<DocumentLineNodeID> = []
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
                layoutLineFragmentView(for: lineFragmentController, lineYPosition: lineYPosition, lineFragmentFrame: &lineFragmentFrame)
                maxY = lineFragmentFrame.maxY
            }
            // The line fragments have now been created and we can set the marked and highlighted ranges on them.
            if let markedRange = markedRange {
                let localMarkedRange = NSRange(globalRange: markedRange, cappedLocalTo: lineController.line)
                lineController.setMarkedTextOnLineFragments(localMarkedRange)
            } else {
                lineController.setMarkedTextOnLineFragments(nil)
            }
            layoutHighlightViews(forLineWithID: line.id)
            let stoppedGeneratingLineFragments = lineFragmentControllers.isEmpty
            let lineSize = CGSize(width: lineController.lineWidth, height: lineController.lineHeight)
            setSize(of: lineController.line, to: lineSize)
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
        linesContainerView.frame = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
        // Update the visible lines and line fragments. Clean up everything that is not in the viewport anymore.
        visibleLineIDs = appearedLineIDs
        let disappearedLineIDs = oldVisibleLineIDs.subtracting(appearedLineIDs)
        let disappearedLineFragmentIDs = oldVisibleLineFragmentIDs.subtracting(appearedLineFragmentIDs)
        let disappearedHighlightViewIDs: Set<String> = disappearedLineIDs.reduce(into: []) { partialResult, lineID in
            if let highlightRects = highlightRectsForLineIDs[lineID] {
                let ids = Set(highlightRects.map(\.id))
                partialResult.formUnion(ids)
            }
        }
        for disappearedLineID in disappearedLineIDs {
            let lineController = lineControllerStorage[disappearedLineID]
            lineController?.cancelSyntaxHighlighting()
        }
        lineNumberLabelReuseQueue.enqueueViews(withKeys: disappearedLineIDs)
        lineFragmentViewReuseQueue.enqueueViews(withKeys: disappearedLineFragmentIDs)
        highlightViewReuseQueue.enqueueViews(withKeys: disappearedHighlightViewIDs)
        // Update content size if necessary.
        if _textContentWidth != oldTextContentWidth || _textContentHeight != oldTextContentHeight {
            delegate?.layoutManagerDidInvalidateContentSize(self)
        }
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
        let xPosition = safeAreaInset.left + gutterLeadingPadding
        var yPosition = textContainerInset.top + line.yPosition
        if lineController.numberOfLineFragments > 1 {
            // There are more than one line fragments, so we align the line number number at the top.
            yPosition += (fontLineHeight * lineHeightMultiplier - fontLineHeight) / 2
        } else {
            // There's a single line fragment, so we center the line number in the height of the line.
            yPosition += (lineController.lineHeight - fontLineHeight) / 2
        }
        lineNumberView.text = "\(line.index + 1)"
        lineNumberView.font = theme.lineNumberFont
        lineNumberView.textColor = theme.lineNumberColor
        lineNumberView.frame = CGRect(x: xPosition, y: yPosition, width: lineNumberWidth, height: fontLineHeight)
    }

    private func layoutLineFragmentView(for lineFragmentController: LineFragmentController, lineYPosition: CGFloat, lineFragmentFrame: inout CGRect) {
        let lineFragment = lineFragmentController.lineFragment
        let lineFragmentView = lineFragmentViewReuseQueue.dequeueView(forKey: lineFragment.id)
        if lineFragmentView.superview == nil {
            linesContainerView.addSubview(lineFragmentView)
        }
        lineFragmentController.invisibleCharacterConfiguration = invisibleCharacterConfiguration
        lineFragmentController.lineFragmentView = lineFragmentView
        let lineFragmentOrigin = CGPoint(x: leadingLineSpacing, y: textContainerInset.top + lineYPosition + lineFragment.yPosition)
        let lineFragmentSize = CGSize(width: lineFragment.scaledSize.width + maximumLineBreakSymbolWidth, height: lineFragment.scaledSize.height)
        lineFragmentFrame = CGRect(origin: lineFragmentOrigin, size: lineFragmentSize)
        lineFragmentView.frame = lineFragmentFrame
    }

    private func layoutHighlightViews(forLineWithID lineID: DocumentLineNodeID) {
        let highlightRects = highlightRects(forLineWithID: lineID)
        for highlightRect in highlightRects {
            let view = highlightViewReuseQueue.dequeueView(forKey: highlightRect.id)
            view.update(with: highlightRect)
            if view.superview == nil {
                highlightsContainerBackgroundView.addSubview(view)
            }
        }
    }

    private func highlightRects(forLineWithID lineID: DocumentLineNodeID) -> [CachedHighlightRect] {
        if let rects = highlightRectsForLineIDs[lineID] {
            return rects
        } else {
            let highlightedRanges = highlightedRangesMap[lineID] ?? []
            let rects: [CachedHighlightRect] = highlightedRanges.flatMap { highlightedRange -> [CachedHighlightRect] in
                let selectionRects = selectionRects(in: highlightedRange.range)
                return selectionRects.map { selectionRect in
                    return CachedHighlightRect(highlightedRange: highlightedRange, selectionRect: selectionRect)
                }
            }
            highlightRectsForLineIDs[lineID] = rects
            return rects
        }
    }

    private func clearHighlightedViews() {
        let keys = Set(highlightViewReuseQueue.visibleViews.keys)
        highlightViewReuseQueue.enqueueViews(withKeys: keys)
    }

    private func setSize(of line: DocumentLineNode, to newSize: CGSize) {
        let lineWidth = newSize.width
        if lineWidths[line.id] != lineWidth {
            lineWidths[line.id] = lineWidth
            if let lineIDTrackingWidth = lineIDTrackingWidth {
                let maximumLineWidth = lineWidths[lineIDTrackingWidth] ?? 0
                if line.id == lineIDTrackingWidth || lineWidth > maximumLineWidth {
                    self.lineIDTrackingWidth = line.id
                    _textContentWidth = nil
                }
            } else if !isLineWrappingEnabled {
                _textContentWidth = nil
            }
        }
        let didUpdateHeight = lineManager.setHeight(of: line, to: newSize.height)
        if didUpdateHeight {
            _textContentHeight = nil
        }
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
        highlightsContainerBackgroundView.removeFromSuperview()
        linesContainerView.removeFromSuperview()
        gutterContainerView.removeFromSuperview()
        gutterBackgroundView.removeFromSuperview()
        gutterSelectionBackgroundView.removeFromSuperview()
        lineNumbersContainerView.removeFromSuperview()
        let allLineNumberKeys = lineFragmentViewReuseQueue.visibleViews.keys
        lineFragmentViewReuseQueue.enqueueViews(withKeys: Set(allLineNumberKeys))
        // Add views to view hierarchy
        textInputView?.addSubview(lineSelectionBackgroundView)
        textInputView?.addSubview(highlightsContainerBackgroundView)
        textInputView?.addSubview(linesContainerView)
        scrollView?.addSubview(gutterContainerView)
        gutterContainerView.addSubview(gutterBackgroundView)
        gutterContainerView.addSubview(gutterSelectionBackgroundView)
        gutterContainerView.addSubview(lineNumbersContainerView)
    }

    private func updateShownViews() {
        let selectedLength = selectedRange?.length ?? 0
        gutterBackgroundView.isHidden = !showLineNumbers
        lineNumbersContainerView.isHidden = !showLineNumbers
        gutterSelectionBackgroundView.isHidden = !lineSelectionDisplayType.shouldShowLineSelection || !showLineNumbers || !isEditing
        lineSelectionBackgroundView.isHidden = !lineSelectionDisplayType.shouldShowLineSelection || !isEditing || selectedLength > 0
    }

    // Resetting the line widths clears all recorded line widths, asks the line manager for the longest line measures the width of the line and uses it to determine the width of content. This is used when first opening the text editor to make a fairly accurate guess of the content width.
    private func resetLineWidthsIfNecessary() {
        if shouldResetLineWidths {
            shouldResetLineWidths = false
            lineWidths = [:]
            if let longestLine = lineManager.initialLongestLine {
                lineIDTrackingWidth = longestLine.id
                let lineController = lineControllerStorage.getOrCreateLineController(for: longestLine)
                lineController.invalidateEverything()
                lineWidths[longestLine.id] = lineController.lineWidth
                if !isLineWrappingEnabled {
                    _textContentWidth = nil
                    delegate?.layoutManagerDidInvalidateContentSize(self)
                }
            }
        }
    }
}

// MARK: - Marked Text
private extension LayoutManager {
    private func updateMarkedTextOnVisibleLines() {
        for lineID in visibleLineIDs {
            if let lineController = lineControllerStorage[lineID] {
                if let markedRange = markedRange {
                    let localMarkedRange = NSRange(globalRange: markedRange, cappedLocalTo: lineController.line)
                    lineController.setMarkedTextOnLineFragments(localMarkedRange)
                } else {
                    lineController.setMarkedTextOnLineFragments(nil)
                }
            }
        }
    }
}

// MARK: - Highlight
private extension LayoutManager {
    private func recreateHighlightedRangesMap() {
        highlightedRangesMap.removeAll()
        for highlightedRange in highlightedRanges where highlightedRange.range.length > 0 {
            let lines = lineManager.lines(in: highlightedRange.range)
            for line in lines {
                if let cappedRange = NSRange(globalRange: highlightedRange.range, cappedTo: line) {
                    let id = highlightedRange.id
                    let color = highlightedRange.color
                    let cornerRadius = highlightedRange.cornerRadius
                    let highlightedRange = HighlightedRange(id: id, range: cappedRange, color: color, cornerRadius: cornerRadius)
                    if let existingHighlightedRanges = highlightedRangesMap[line.id] {
                        highlightedRangesMap[line.id] = existingHighlightedRanges + [highlightedRange]
                    } else {
                        highlightedRangesMap[line.id] = [highlightedRange]
                    }
                }
            }
        }
    }
}

// MARK: - Memory Management
private extension LayoutManager {
    @objc private func clearMemory() {
        lineControllerStorage.removeAllLineControllers(exceptLinesWithID: visibleLineIDs)
    }
}
