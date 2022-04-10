// swiftlint:disable file_length

import UIKit

protocol LayoutManagerDelegate: AnyObject {
    func layoutManagerDidInvalidateContentSize(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint)
    func layoutManagerDidUpdateGutterWidth(_ layoutManager: LayoutManager)
    func layoutManagerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ layoutManager: LayoutManager)
}

// swiftlint:disable:next type_body_length
final class LayoutManager {
    weak var delegate: LayoutManagerDelegate?
    weak var editorView: UIScrollView? {
        didSet {
            if editorView != oldValue {
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
            if scrollViewWidth != oldValue {
                if isLineWrappingEnabled {
                    invalidateContentSize()
                    invalidateLines()
                }
            }
        }
    }
    var scrollViewSafeAreaInsets: UIEdgeInsets = .zero {
        didSet {
            if scrollViewSafeAreaInsets != oldValue {
                if isLineWrappingEnabled {
                    invalidateContentSize()
                    invalidateLines()
                }
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
                for (_, lineController) in lineControllers {
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
                for (_, lineController) in lineControllers {
                    lineController.theme = theme
                    lineController.estimatedLineFragmentHeight = theme.font.totalLineHeight
                    lineController.invalidateSyntaxHighlighting()
                }
                updateLineNumberWidth()
                if theme.font != oldValue.font {
                    invalidateContentSize()
                }
                setNeedsLayout()
                setNeedsLayoutSelection()
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
                setNeedsLayoutSelection()
                layoutSelectionIfNeeded()
                updateShownViews()
            }
        }
    }
    var invisibleCharacterConfiguration = InvisibleCharacterConfiguration()
    var tabWidth: CGFloat = 10 {
        didSet {
            if tabWidth != oldValue {
                invalidateContentSize()
                invalidateLines()
            }
        }
    }
    var isLineWrappingEnabled = true {
        didSet {
            if isLineWrappingEnabled != oldValue {
                invalidateContentSize()
                invalidateLines()
            }
        }
    }
    var gutterLeadingPadding: CGFloat = 3 {
        didSet {
            if gutterLeadingPadding != oldValue {
                invalidateContentSize()
            }
        }
    }
    var gutterTrailingPadding: CGFloat = 3 {
        didSet {
            if gutterTrailingPadding != oldValue {
                invalidateContentSize()
            }
        }
    }
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
                invalidateLines()
            }
        }
    }
    var kern: CGFloat = 0 {
        didSet {
            if lineHeightMultiplier != oldValue {
                invalidateContentSize()
                invalidateLines()
            }
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
                recreateHighlightedRangesMap()
                updateHighlightedRangesOnVisibleLines()
            }
        }
    }
    private var highlightedRangesMap: [DocumentLineNodeID: [HighlightedRange]] = [:]

    // MARK: - Views
    let gutterContainerView = UIView()
    private var lineFragmentViewReuseQueue = ViewReuseQueue<LineFragmentID, LineFragmentView>()
    private var lineNumberLabelReuseQueue = ViewReuseQueue<DocumentLineNodeID, LineNumberView>()
    private var visibleLineIDs: Set<DocumentLineNodeID> = []
    private let linesContainerView = UIView()
    private let gutterBackgroundView = GutterBackgroundView()
    private let lineNumbersContainerView = UIView()
    private let gutterSelectionBackgroundView = UIView()
    private let lineSelectionBackgroundView = UIView()

    // MARK: - Sizing
    private var contentWidth: CGFloat {
        if isLineWrappingEnabled {
            return scrollViewWidth - scrollViewSafeAreaInsets.left - scrollViewSafeAreaInsets.right
        } else {
            return ceil(textContentWidth + leadingLineSpacing + textContainerInset.right + maximumLineBreakymbolWidth)
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
    private var leadingLineSpacing: CGFloat {
        if showLineNumbers {
            return gutterWidth + textContainerInset.left
        } else {
            return textContainerInset.left
        }
    }
    // Reset the line widths when changing the line manager to measure the
    // longest line and use it to determine the content width.
    private var shouldResetLineWidths = true
    private var lineWidths: [DocumentLineNodeID: CGFloat] = [:]
    private var lineIDTrackingWidth: DocumentLineNodeID?
    private var maximumLineWidth: CGFloat {
        if isLineWrappingEnabled {
            return scrollViewWidth - leadingLineSpacing - textContainerInset.right - scrollViewSafeAreaInsets.left - scrollViewSafeAreaInsets.right
        } else {
            // Rendering multiple very long lines is very expensive. In order to let the editor remain useable,
            // we set a very high maximum line width when line wrapping is disabled.
            return 10_000
        }
    }
    private var insetViewport: CGRect {
        let x = viewport.minX - textContainerInset.left
        let y = viewport.minY - textContainerInset.top
        let width = viewport.width + textContainerInset.left + textContainerInset.right
        let height = viewport.height + textContainerInset.top + textContainerInset.bottom
        return CGRect(x: x, y: y, width: width, height: height)
    }
    private var additionalInset: UIEdgeInsets {
        if let editorView = editorView {
            let adjustContentInset = editorView.adjustedContentInset
            let contentInset = editorView.contentInset
            let top = adjustContentInset.top - contentInset.top
            let left = adjustContentInset.left - contentInset.left
            let bottom = adjustContentInset.bottom - contentInset.bottom
            let right = adjustContentInset.right - contentInset.right
            return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        } else {
            return .zero
        }
    }

    // MARK: - Rendering
    private var lineControllers: [DocumentLineNodeID: LineController] = [:]
    private var needsLayout = false
    private var needsLayoutSelection = false
    private var maximumLineBreakymbolWidth: CGFloat {
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

    init(lineManager: LineManager, languageMode: InternalLanguageMode, stringView: StringView) {
        self.lineManager = lineManager
        self.languageMode = languageMode
        self.stringView = stringView
        self.linesContainerView.isUserInteractionEnabled = false
        self.lineNumbersContainerView.isUserInteractionEnabled = false
        self.gutterContainerView.isUserInteractionEnabled = false
        self.gutterBackgroundView.isUserInteractionEnabled = false
        self.gutterSelectionBackgroundView.isUserInteractionEnabled = false
        self.lineSelectionBackgroundView.isUserInteractionEnabled = false
        self.updateShownViews()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemory),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
    }

    func invalidateContentSize() {
        _textContentWidth = nil
        _textContentHeight = nil
    }

    func removeLine(withID lineID: DocumentLineNodeID) {
        lineWidths.removeValue(forKey: lineID)
        lineControllers.removeValue(forKey: lineID)
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
                delegate?.layoutManagerDidUpdateGutterWidth(self)
                _textContentWidth = nil
                delegate?.layoutManagerDidInvalidateContentSize(self)
            }
        }
    }

    func invalidateLines() {
        for (_, lineController) in lineControllers {
            lineController.lineFragmentHeightMultiplier = lineHeightMultiplier
            lineController.tabWidth = tabWidth
            lineController.kern = kern
            lineController.invalidateSyntaxHighlighting()
        }
    }

    func redisplay(_ lines: Set<DocumentLineNode>) {
        for line in lines {
            if let lineController = lineControllers[line.id] {
                let lineYPosition = line.yPosition
                let lineLocalViewport = CGRect(x: 0, y: lineYPosition, width: insetViewport.width, height: insetViewport.maxY - lineYPosition)
                lineController.invalidateEverything()
                lineController.prepareToDisplayString(in: lineLocalViewport, syntaxHighlightAsynchronously: false)
            }
        }
    }

    func setNeedsDisplayOnLines() {
        for (_, lineController) in lineControllers {
            lineController.setNeedsDisplayOnLineFragmentViews()
        }
    }

    func typesetLines(to location: Int) {
        let range = NSRange(location: 0, length: location)
        let lines = lineManager.lines(in: range)
        for line in lines {
            let lineController = lineController(for: line)
            let lineLocation = line.location
            let endTypesettingLocation = min(lineLocation + line.data.length, location) - lineLocation
            lineController.prepareToDisplayString(toLocation: endTypesettingLocation, syntaxHighlightAsynchronously: true)
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
        let lineControllers = lines.map(lineController(for:))
        let localNeedleLocation = needleRange.location - startLocation
        let localNeedleLength = min(needleRange.length, previewRange.length)
        let needleInPreviewRange = NSRange(location: localNeedleLocation, length: localNeedleLength)
        return TextPreview(
            needleRange: needleRange,
            previewRange: previewRange,
            needleInPreviewRange: needleInPreviewRange,
            lineControllers: lineControllers)
    }
}

// MARK: - UITextInput
extension LayoutManager {
    func caretRect(at location: Int) -> CGRect {
        let line = lineManager.line(containingCharacterAt: location)!
        let lineController = lineController(for: line)
        let localLocation = location - line.location
        let localCaretRect = lineController.caretRect(atIndex: localLocation)
        let globalYPosition = line.yPosition + localCaretRect.minY
        let globalRect = CGRect(x: localCaretRect.minX, y: globalYPosition, width: localCaretRect.width, height: localCaretRect.height)
        return globalRect.offsetBy(dx: leadingLineSpacing, dy: textContainerInset.top)
    }

    func firstRect(for range: NSRange) -> CGRect {
        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        let lineController = lineController(for: line)
        let localRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
        let lineContentsRect = lineController.firstRect(for: localRange)
        let visibleWidth = viewport.width - gutterWidth
        let xPosition = lineContentsRect.minX + textContainerInset.left + gutterWidth
        let yPosition = line.yPosition + lineContentsRect.minY + textContainerInset.top
        let width = min(lineContentsRect.width, visibleWidth)
        return CGRect(x: xPosition, y: yPosition, width: width, height: lineContentsRect.height)
    }

    func selectionRects(in range: NSRange) -> [TextSelectionRect] {
        guard let startLine = lineManager.line(containingCharacterAt: range.location) else {
            return []
        }
        guard let endLine = lineManager.line(containingCharacterAt: range.location + range.length) else {
            return []
        }
        var selectionRects: [TextSelectionRect] = []
        let startLineIndex = startLine.index
        let endLineIndex = endLine.index
        let lineIndexRange = startLineIndex ..< endLineIndex + 1
        for lineIndex in lineIndexRange {
            let line = lineManager.line(atRow: lineIndex)
            let lineController = lineController(for: line)
            let lineStartLocation = line.location
            let lineEndLocation = lineStartLocation + line.data.totalLength
            let localRangeLocation = max(range.location, lineStartLocation) - lineStartLocation
            let localRangeLength = min(range.location + range.length, lineEndLocation) - lineStartLocation - localRangeLocation
            let localRange = NSRange(location: localRangeLocation, length: localRangeLength)
            let lineFragmentSelectionRects = lineController.selectionRects(in: localRange)
            for (lineFragmentSelectionRectIdx, lineFragmentSelectionRect) in lineFragmentSelectionRects.enumerated() {
                // Determining containsStart and containsEnd based on indices assumes that the text selection rects are iterated in order.
                // This means that `-selectionRects(in:)` on LineController should return them in order.
                let containsStart = lineIndex == lineIndexRange.lowerBound && lineFragmentSelectionRectIdx == 0
                let containsEnd = lineIndex == lineIndexRange.upperBound - 1 && lineFragmentSelectionRectIdx == lineFragmentSelectionRects.count - 1
                var screenRect = lineFragmentSelectionRect.rect
                screenRect.origin.x += leadingLineSpacing
                screenRect.origin.y = textContainerInset.top + line.yPosition + lineFragmentSelectionRect.rect.minY
                if !containsEnd {
                    // If the following lines are selected, we make sure that the selections extends the entire line.
                    screenRect.size.width = max(contentWidth, scrollViewWidth) - screenRect.minX
                }
                selectionRects += [
                    TextSelectionRect(rect: screenRect, writingDirection: .natural, containsStart: containsStart, containsEnd: containsEnd)
                ]
            }
        }
        return selectionRects.ensuringYAxisAlignment()
    }

    func closestIndex(to point: CGPoint) -> Int? {
        let adjustedXPosition = point.x - leadingLineSpacing
        let adjustedYPosition = point.y - textContainerInset.top
        let adjustedPoint = CGPoint(x: adjustedXPosition, y: adjustedYPosition)
        if let line = lineManager.line(containingYOffset: adjustedPoint.y), let lineController = lineControllers[line.id] {
            return closestIndex(to: adjustedPoint, in: lineController, showing: line)
        } else if adjustedPoint.y <= 0 {
            let firstLine = lineManager.firstLine
            if let textRenderer = lineControllers[firstLine.id] {
                return closestIndex(to: adjustedPoint, in: textRenderer, showing: firstLine)
            } else {
                return 0
            }
        } else {
            let lastLine = lineManager.lastLine
            if adjustedPoint.y >= lastLine.yPosition, let textRenderer = lineControllers[lastLine.id] {
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
            CATransaction.commit()
        }
    }

    func setNeedsLayoutSelection() {
        needsLayoutSelection = true
    }

    func layoutSelectionIfNeeded() {
        if needsLayoutSelection {
            needsLayoutSelection = true
            CATransaction.begin()
            CATransaction.setDisableActions(false)
            layoutLineSelection()
            updateLineNumberColors()
            CATransaction.commit()
        }
    }

    private func layoutGutter() {
        let totalGutterWidth = additionalInset.left + gutterWidth
        gutterContainerView.frame = CGRect(x: viewport.minX, y: 0, width: totalGutterWidth, height: contentSize.height)
        gutterBackgroundView.frame = CGRect(x: 0, y: viewport.minY, width: totalGutterWidth, height: viewport.height)
        lineNumbersContainerView.frame = CGRect(x: 0, y: 0, width: totalGutterWidth, height: contentSize.height)
    }

    private func layoutLineSelection() {
        guard lineSelectionDisplayType.shouldShowLineSelection, let selectedRange = selectedRange else {
            return
        }
        let startLocation = selectedRange.location
        let endLocation = selectedRange.location + selectedRange.length
        let selectedRect: CGRect
        if selectedRange.nonNegativeLength.length > 0 {
            let startSelectionRect = selectionRectangleForLineFragment(containingCharacterAt: startLocation)
            let endSelectionRect = selectionRectangleForLineFragment(containingCharacterAt: endLocation)
            let height = endSelectionRect.maxY - startSelectionRect.minY
            selectedRect = CGRect(x: 0, y: startSelectionRect.minY, width: scrollViewWidth, height: height)
        } else {
            let selectionRect = selectionRectangleForLineFragment(containingCharacterAt: startLocation)
            selectedRect = CGRect(x: 0, y: selectionRect.minY, width: scrollViewWidth, height: selectionRect.height)
        }
        let totalGutterWidth = additionalInset.left + gutterWidth
        gutterSelectionBackgroundView.frame = CGRect(x: 0, y: selectedRect.minY, width: totalGutterWidth, height: selectedRect.height)
        let lineSelectionBackgroundOrigin = CGPoint(x: viewport.minX + totalGutterWidth, y: selectedRect.minY)
        let lineSelectionBackgroundSize = CGSize(width: scrollViewWidth - gutterWidth, height: selectedRect.height)
        lineSelectionBackgroundView.frame = CGRect(origin: lineSelectionBackgroundOrigin, size: lineSelectionBackgroundSize)
    }

    private func selectionRectangleForLineFragment(containingCharacterAt location: Int) -> CGRect {
        switch lineSelectionDisplayType {
        case .disabled:
            return .null
        case .line:
            let line = lineManager.line(containingCharacterAt: location)!
            return CGRect(x: 0, y: textContainerInset.top + line.yPosition, width: scrollViewWidth, height: line.data.lineHeight)
        case .lineFragment:
            let caretRect = caretRect(at: location)
            let lineFragmentHeight = caretRect.height * lineHeightMultiplier
            let lineFragmentYPosition = caretRect.minY + (caretRect.height - lineFragmentHeight) / 2
            return CGRect(x: 0, y: lineFragmentYPosition, width: scrollViewWidth, height: lineFragmentHeight)
        }
    }

    func layoutLines(untilLocation location: Int) {
        var nextLine: DocumentLineNode? = lineManager.firstLine
        let isLocationEndOfString = location >= stringView.string.length
        while let line = nextLine {
            let lineLocation = line.location
            let endTypesettingLocation = min(lineLocation + line.data.length, location) - lineLocation
            let lineController = lineController(for: line)
            lineController.constrainingWidth = maximumLineWidth
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
    }

    // swiftlint:disable:next function_body_length
    private func layoutLinesInViewport() {
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
        while let line = nextLine, maxY < insetViewport.maxY, maximumLineWidth > 0 {
            appearedLineIDs.insert(line.id)
            // Prepare to line controller to display text.
            let lineLocalViewport = CGRect(x: 0, y: maxY, width: insetViewport.width, height: insetViewport.maxY - maxY)
            let lineController = lineController(for: line)
            let oldLineHeight = lineController.lineHeight
            lineController.constrainingWidth = maximumLineWidth
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
                let localMarkedRange = NSRange(globalRange: markedRange, localTo: lineController.line)
                lineController.setMarkedTextOnLineFragments(localMarkedRange)
            } else {
                lineController.setMarkedTextOnLineFragments(nil)
            }
            let highlightedRanges = highlightedRangesMap[line.id] ?? []
            lineController.setHighlightedRangesOnLineFragments(highlightedRanges)
            // If we found at least one line to be shown and now aren't getting any line fragments within the viewport
            // then there's no more line fragments to be shown in the viewport and we stop generating line fragments.
            var stoppedGeneratingLineFragments = false
            if !appearedLineFragmentIDs.isEmpty {
                stoppedGeneratingLineFragments = lineFragmentControllers.isEmpty
            }
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
        for disapparedLineID in disappearedLineIDs {
            let lineController = lineControllers[disapparedLineID]
            lineController?.cancelSyntaxHighlighting()
        }
        lineNumberLabelReuseQueue.enqueueViews(withKeys: disappearedLineIDs)
        lineFragmentViewReuseQueue.enqueueViews(withKeys: disappearedLineFragmentIDs)
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
        let lineController = lineController(for: line)
        let fontLineHeight = theme.font.lineHeight
        let xPosition = additionalInset.left + gutterLeadingPadding
        var yPosition = textContainerInset.top + line.yPosition
        if lineController.numberOfLineFragments > 1 {
            // There are more than one line fragments, so we align the line number number at the top.
            yPosition += (fontLineHeight * lineHeightMultiplier - fontLineHeight) / 2
        } else {
            // There's a single line fragment, so we center the line number in the height of the line.
            yPosition += (lineController.lineHeight - fontLineHeight) / 2
        }
        lineNumberView.text = "\(line.index + 1)"
        lineNumberView.font = theme.font
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
        let lineFragmentSize = CGSize(width: lineFragment.scaledSize.width + maximumLineBreakymbolWidth, height: lineFragment.scaledSize.height)
        lineFragmentFrame = CGRect(origin: lineFragmentOrigin, size: lineFragmentSize)
        lineFragmentView.frame = lineFragmentFrame
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
        gutterBackgroundView.removeFromSuperview()
        lineNumbersContainerView.removeFromSuperview()
        gutterSelectionBackgroundView.removeFromSuperview()
        lineSelectionBackgroundView.removeFromSuperview()
        let allLineNumberKeys = lineFragmentViewReuseQueue.visibleViews.keys
        lineFragmentViewReuseQueue.enqueueViews(withKeys: Set(allLineNumberKeys))
        // Add views to view hierarchy
        textInputView?.addSubview(lineSelectionBackgroundView)
        textInputView?.addSubview(linesContainerView)
        editorView?.addSubview(gutterContainerView)
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

    // Resetting the line widths clears all recorded line widths, asks the line manager for the longest line,
    // measures the width of the line and uses it to determine the width of content.
    // This is used when first opening the text editor to make a fairly accurate guess of the content width.
    private func resetLineWidthsIfNecessary() {
        if shouldResetLineWidths {
            shouldResetLineWidths = false
            lineWidths = [:]
            if let longestLine = lineManager.initialLongestLine {
                lineIDTrackingWidth = longestLine.id
                let lineController = lineController(for: longestLine)
                lineController.invalidateEverything()
                lineWidths[longestLine.id] = lineController.lineWidth
                if !isLineWrappingEnabled {
                    _textContentWidth = nil
                    delegate?.layoutManagerDidInvalidateContentSize(self)
                }
            }
        }
    }

    private func lineController(for line: DocumentLineNode) -> LineController {
        if let cachedLineController = lineControllers[line.id] {
            return cachedLineController
        } else {
            let lineController = LineController(line: line, stringView: stringView)
            lineController.delegate = self
            lineController.constrainingWidth = maximumLineWidth
            lineController.estimatedLineFragmentHeight = theme.font.totalLineHeight
            lineController.lineFragmentHeightMultiplier = lineHeightMultiplier
            lineController.tabWidth = tabWidth
            lineController.theme = theme
            lineControllers[line.id] = lineController
            return lineController
        }
    }
}

// MARK: - Line Movement
extension LayoutManager {
    func numberOfLineFragments(in line: DocumentLineNode) -> Int {
        return lineController(for: line).numberOfLineFragments
    }

    func lineFragmentNode(atIndex index: Int, in line: DocumentLineNode) -> LineFragmentNode {
        return lineController(for: line).lineFragmentNode(atIndex: index)
    }

    func lineFragmentNode(containingCharacterAt location: Int, in line: DocumentLineNode) -> LineFragmentNode {
        return lineController(for: line).lineFragmentNode(containingCharacterAt: location)
    }
}

// MARK: - Marked Text
private extension LayoutManager {
    private func updateMarkedTextOnVisibleLines() {
        for lineID in visibleLineIDs {
            if let lineController = lineControllers[lineID] {
                if let markedRange = markedRange {
                    let localMarkedRange = NSRange(globalRange: markedRange, localTo: lineController.line)
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
                if let cappedRange = NSRange(globalRange: highlightedRange.range, localTo: line) {
                    let highlightedRange = HighlightedRange(
                        id: highlightedRange.id,
                        range: cappedRange,
                        color: highlightedRange.color,
                        cornerRadius: highlightedRange.cornerRadius)
                    if let existingHighlightedRanges = highlightedRangesMap[line.id] {
                        highlightedRangesMap[line.id] = existingHighlightedRanges + [highlightedRange]
                    } else {
                        highlightedRangesMap[line.id] = [highlightedRange]
                    }
                }
            }
        }
    }

    private func updateHighlightedRangesOnVisibleLines() {
        for lineID in visibleLineIDs {
            if let lineController = lineControllers[lineID] {
                let highlightedRanges = highlightedRangesMap[lineID] ?? []
                lineController.setHighlightedRangesOnLineFragments(highlightedRanges)
            }
        }
    }
}

// MARK: - Memory Management
private extension LayoutManager {
    @objc private func clearMemory() {
        let allLineIDs = Set(lineControllers.keys)
        let lineIDsToRelease = allLineIDs.subtracting(visibleLineIDs)
        for lineID in lineIDsToRelease {
            lineControllers.removeValue(forKey: lineID)
        }
    }
}

// MARK: - LineControllerDelegate
extension LayoutManager: LineControllerDelegate {
    func lineSyntaxHighlighter(for lineController: LineController) -> LineSyntaxHighlighter? {
        let syntaxHighlighter = languageMode.createLineSyntaxHighlighter()
        syntaxHighlighter.kern = kern
        return syntaxHighlighter
    }

    func lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ lineController: LineController) {
        delegate?.layoutManagerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(self)
    }
}
