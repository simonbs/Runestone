//
//  LayoutManager.swift
//  
//
//  Created by Simon Støvring on 25/01/2021.
//

import UIKit

protocol LayoutManagerDelegate: AnyObject {
    func layoutManager(_ layoutManager: LayoutManager, stringIn range: NSRange) -> String
    func layoutManagerDidInvalidateContentSize(_ layoutManager: LayoutManager)
    func lengthOfString(in layoutManager: LayoutManager) -> Int
}

final class LayoutManager {
    // MARK: - Public
    weak var delegate: LayoutManagerDelegate?
    weak var editorView: UIView? {
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
    var lineManager: LineManager
    var frame: CGRect = .zero {
        didSet {
            if frame.size.width != oldValue.size.width {
                if isLineWrappingEnabled {
                    invalidateTypesetting()
                }
            }
        }
    }
    var viewport: CGRect = .zero
    var contentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }
    var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            if theme !== oldValue {
                gutterBackgroundView.backgroundColor = theme.gutterBackgroundColor
                gutterBackgroundView.hairlineColor = theme.gutterHairlineColor
                gutterBackgroundView.hairlineWidth = theme.gutterHairlineWidth
                gutterSelectionBackgroundView.backgroundColor = theme.selectedLinesGutterBackgroundColor
                lineSelectionBackgroundView.backgroundColor = theme.selectedLineBackgroundColor
                invalidateSyntaxHighlighting()
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
                    updateGutterWidth()
                }
            }
        }
    }
    var showSelectedLines = false {
        didSet {
            if showSelectedLines != oldValue {
                updateShownViews()
            }
        }
    }
    var invisibleCharacterConfiguration = InvisibleCharacterConfiguration()
    var isLineWrappingEnabled = true {
        didSet {
            if isLineWrappingEnabled != oldValue {
                invalidateContentSize()
                invalidateTypesetting()
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
    var gutterMargin: CGFloat = 5 {
        didSet {
            if gutterMargin != oldValue {
                invalidateContentSize()
            }
        }
    }
    var lineMargin: CGFloat = 5 {
        didSet {
            if lineMargin != oldValue {
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

    // MARK: - Views
    let gutterContainerView = UIView()
    private var lineViewReuseQueue = ViewReuseQueue<DocumentLineNodeID, LineView>()
    private var lineNumberLabelReuseQueue = ViewReuseQueue<DocumentLineNodeID, LineNumberView>()
    private let linesContainerView = UIView()
    private let gutterBackgroundView = GutterBackgroundView()
    private let lineNumbersContainerView = UIView()
    private let gutterSelectionBackgroundView = UIView()
    private let lineSelectionBackgroundView = UIView()

    // MARK: - Sizing
    private var contentWidth: CGFloat {
        if let contentWidth = _contentWidth {
            return contentWidth
        } else if isLineWrappingEnabled {
            let contentWidth = frame.width
            _contentWidth = contentWidth
            return contentWidth
        } else {
            lineIDTrackingWidth = nil
            var currentMaximumWidth: CGFloat?
            for (lineID, lineWidth) in lineWidths {
                if let _currentMaximumWidth = currentMaximumWidth {
                    if lineWidth > _currentMaximumWidth {
                        lineIDTrackingWidth = lineID
                        currentMaximumWidth = lineWidth
                    }
                } else {
                    lineIDTrackingWidth = lineID
                    currentMaximumWidth = lineWidth
                }
            }
            let contentWidth = currentMaximumWidth ?? frame.width
            _contentWidth = contentWidth + leadingLineSpacing + lineMargin
            return contentWidth
        }
    }
    private var contentHeight: CGFloat {
        if let contentHeight = _contentHeight {
            return contentHeight
        } else {
            let contentHeight = lineManager.contentHeight
            _contentHeight = contentHeight
            return contentHeight
        }
    }
    private var _contentWidth: CGFloat?
    private var _contentHeight: CGFloat?
    private var lineNumberWidth: CGFloat = 0
    private var previousGutterWidthUpdateLineCount: Int?
    private var leadingLineSpacing: CGFloat {
        if showLineNumbers {
            return gutterWidth + gutterMargin
        } else {
            return 0
        }
    }

    // MARK: - Rendering
    private let operationQueue: OperationQueue
    private let syntaxHighlighter: SyntaxHighlighter
    private var lineControllers: [DocumentLineNodeID: LineController] = [:]
    private var needsLayout = false
    private var needsLayoutSelection = false
    private var lineWidths: [DocumentLineNodeID: CGFloat] = [:]
    private var lineIDTrackingWidth: DocumentLineNodeID?

    // MARK: - Helpers
    private var currentDelegate: LayoutManagerDelegate {
        if let delegate = delegate {
            return delegate
        } else {
            fatalError("Delegate unavailable")
        }
    }

    init(lineManager: LineManager, syntaxHighlighter: SyntaxHighlighter, operationQueue: OperationQueue) {
        self.lineManager = lineManager
        self.syntaxHighlighter = syntaxHighlighter
        self.operationQueue = operationQueue
        self.linesContainerView.isUserInteractionEnabled = false
        self.lineNumbersContainerView.isUserInteractionEnabled = false
        self.gutterContainerView.isUserInteractionEnabled = false
        self.gutterBackgroundView.isUserInteractionEnabled = false
        self.gutterSelectionBackgroundView.isUserInteractionEnabled = false
        self.lineSelectionBackgroundView.isUserInteractionEnabled = false
        self.updateShownViews()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning(_:)),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
    }

    func setNeedsLayout() {
        needsLayout = true
    }

    func layoutIfNeeded() {
        guard needsLayout else {
            return
        }
        needsLayout = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        syntaxHighlighter.prepare()
        layoutGutter()
        layoutSelection()
        updateLineNumberColors()
        let oldVisibleLineIds = Set(lineViewReuseQueue.visibleViews.keys)
        var nextLine = lineManager.line(containingYOffset: viewport.minY)
        var appearedLineIDs: Set<DocumentLineNodeID> = []
        var maxY = viewport.minY
        while let line = nextLine, maxY < viewport.maxY {
            appearedLineIDs.insert(line.id)
            layoutViews(for: line, maxY: &maxY)
            if line.index < lineManager.lineCount - 1 {
                nextLine = lineManager.line(atIndex: line.index + 1)
            } else {
                nextLine = nil
            }
        }
        let disappearedLineIDs = oldVisibleLineIds.subtracting(appearedLineIDs)
        lineViewReuseQueue.enqueueViews(withKeys: disappearedLineIDs)
        lineNumberLabelReuseQueue.enqueueViews(withKeys: disappearedLineIDs)
        if _contentWidth == nil || _contentHeight == nil {
            delegate?.layoutManagerDidInvalidateContentSize(self)
        }
        CATransaction.commit()
    }

    func setNeedsLayoutSelection() {
        needsLayoutSelection = true
    }

    func layoutSelectionIfNeeded() {
        guard needsLayoutSelection else {
            return
        }
        needsLayoutSelection = true
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        layoutSelection()
        updateLineNumberColors()
        CATransaction.commit()
    }

    func invalidateContentSize() {
        _contentWidth = nil
        _contentHeight = nil
    }

    func removeLine(withID lineID: DocumentLineNodeID) {
        if lineID == lineIDTrackingWidth {
            lineIDTrackingWidth = nil
            _contentWidth = nil
            delegate?.layoutManagerDidInvalidateContentSize(self)
        }
        lineWidths.removeValue(forKey: lineID)
        lineControllers.removeValue(forKey: lineID)
    }

    func updateGutterWidth() {
        guard showLineNumbers else {
            return
        }
        let lineCount = lineManager.lineCount
        if lineCount != previousGutterWidthUpdateLineCount {
            previousGutterWidthUpdateLineCount = lineCount
            let characterCount = "\(lineCount)".count
            let wideLineNumberString = String(repeating: "8", count: characterCount)
            let wideLineNumberNSString = wideLineNumberString as NSString
            let size = wideLineNumberNSString.size(withAttributes: [.font: theme.lineNumberFont])
            let oldLineNumberWidth = lineNumberWidth
            lineNumberWidth = ceil(size.width) + gutterLeadingPadding + gutterTrailingPadding
            if lineNumberWidth != oldLineNumberWidth {
                _contentWidth = nil
                delegate?.layoutManagerDidInvalidateContentSize(self)
            }
        }
    }

    func typeset(_ lines: Set<DocumentLineNode>) {
        for line in lines {
            if let lineController = lineControllers[line.id] {
                lineController.typeset()
            }
        }
    }

    func syntaxHighlight(_ lines: Set<DocumentLineNode>) {
        for line in lines {
            if let lineController = lineControllers[line.id] {
                lineController.syntaxHighlight()
            }
        }
    }
}

// MARK: - UITextInput
extension LayoutManager {
    func caretRect(at location: Int) -> CGRect? {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        let lineController = getLineController(for: line)
        let localLocation = location - line.location
        let localCaretRect = lineController.caretRect(atIndex: localLocation)
        let globalYPosition = line.yPosition + localCaretRect.minY
        let globalRect = CGRect(x: localCaretRect.minX, y: globalYPosition, width: localCaretRect.width, height: localCaretRect.height)
        return globalRect.offsetBy(dx: leadingLineSpacing, dy: 0)
    }

    func firstRect(for range: NSRange) -> CGRect {
        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        let lineController = lineControllers[line.id]!
        let localRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
        let firstRect = lineController.firstRect(for: localRange)
        return firstRect.offsetBy(dx: leadingLineSpacing, dy: 0)
    }

    func selectionRects(in range: NSRange) -> [TextSelectionRect] {
        guard let startLine = lineManager.line(containingCharacterAt: range.location) else {
            return []
        }
        guard let endLine = lineManager.line(containingCharacterAt: range.location + range.length) else {
            return []
        }
        var selectionRects: [TextSelectionRect] = []
        let lineIndexRange = startLine.index ..< endLine.index + 1
        for lineIndex in lineIndexRange {
            let line = lineManager.line(atIndex: lineIndex)
            let lineController = getLineController(for: line)
            let lineStartLocation = line.location
            let lineEndLocation = lineStartLocation + line.data.totalLength
            let localRangeLocation = max(range.location, lineStartLocation) - lineStartLocation
            let localRangeLength = min(range.location + range.length, lineEndLocation) - lineStartLocation - localRangeLocation
            let localRange = NSRange(location: localRangeLocation, length: localRangeLength)
            let rendererSelectionRects = lineController.selectionRects(in: localRange)
            let textSelectionRects: [TextSelectionRect] = rendererSelectionRects.map { rendererSelectionRect in
                let y = line.yPosition + rendererSelectionRect.rect.minY
                var screenRect = CGRect(x: rendererSelectionRect.rect.minX, y: y, width: rendererSelectionRect.rect.width, height: rendererSelectionRect.rect.height)
                let startLocation = lineStartLocation + rendererSelectionRect.range.location
                let endLocation = startLocation + rendererSelectionRect.range.length
                let containsStart = range.location >= startLocation && range.location <= endLocation
                let containsEnd = range.location + range.length >= startLocation && range.location + range.length <= endLocation
                screenRect.origin.x += leadingLineSpacing
                if !containsStart {
                    // If this is not the starting line then we ignore the leading line spacing so
                    // the selection rect starts right after the gutter.
                    screenRect.origin.x = gutterWidth
                }
                if endLocation < range.location + range.length {
                    screenRect.size.width = contentWidth - screenRect.minX
                }
                return TextSelectionRect(rect: screenRect, writingDirection: .leftToRight, containsStart: containsStart, containsEnd: containsEnd)
            }
            selectionRects.append(contentsOf: textSelectionRects)
        }
        return selectionRects.ensuringYAxisAlignment()
    }

    func closestIndex(to point: CGPoint) -> Int? {
        if let line = lineManager.line(containingYOffset: point.y), let lineController = lineControllers[line.id] {
            return closestIndex(to: point, in: lineController, showing: line)
        } else if point.y <= 0 {
            let firstLine = lineManager.firstLine
            if let textRenderer = lineControllers[firstLine.id] {
                return closestIndex(to: point, in: textRenderer, showing: firstLine)
            } else {
                return 0
            }
        } else {
            let lastLine = lineManager.lastLine
            if point.y >= lastLine.yPosition, let textRenderer = lineControllers[lastLine.id] {
                return closestIndex(to: point, in: textRenderer, showing: lastLine)
            } else {
                return currentDelegate.lengthOfString(in: self)
            }
        }
    }

    private func closestIndex(to point: CGPoint, in lineController: LineController, showing line: DocumentLineNode) -> Int {
        let localPoint = CGPoint(x: point.x - leadingLineSpacing, y: point.y - lineController.lineViewFrame.minY)
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
    private func layoutGutter() {
        gutterContainerView.frame = CGRect(x: viewport.minX, y: 0, width: gutterWidth, height: contentSize.height)
        gutterBackgroundView.frame = CGRect(x: 0, y: viewport.minY, width: gutterWidth, height: viewport.height)
        lineNumbersContainerView.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: contentSize.height)
    }

    private func layoutSelection() {
        guard showSelectedLines, let selectedRange = selectedRange else {
            return
        }
        let startLocation = selectedRange.location
        let endLocation = selectedRange.location + selectedRange.length
        let selectedRect: CGRect
        if selectedRange.length > 0 {
            let startLine = lineManager.line(containingCharacterAt: startLocation)!
            let endLine = lineManager.line(containingCharacterAt: endLocation)!
            let startLineController = getLineController(for: startLine)
            let endLineController = getLineController(for: endLine)
            let yPos = startLineController.lineViewFrame.minY
            let height = endLineController.lineViewFrame.maxY - startLineController.lineViewFrame.minY
            selectedRect = CGRect(x: 0, y: yPos, width: frame.width, height: height)
        } else {
            let line = lineManager.line(containingCharacterAt: startLocation)!
            let lineController = getLineController(for: line)
            selectedRect = CGRect(x: 0, y: lineController.lineViewFrame.minY, width: frame.width, height: lineController.lineViewFrame.height)
        }
        gutterSelectionBackgroundView.frame = CGRect(x: 0, y: selectedRect.minY, width: gutterWidth, height: selectedRect.height)
        lineSelectionBackgroundView.frame = CGRect(x: viewport.minX + gutterWidth, y: selectedRect.minY, width: frame.width - gutterWidth, height: selectedRect.height)
    }

    private func layoutViews(for line: DocumentLineNode, maxY: inout CGFloat) {
        // Ensure views are added to the view hiearchy
        let lineView = lineViewReuseQueue.dequeueView(forKey: line.id)
        let lineNumberView = lineNumberLabelReuseQueue.dequeueView(forKey: line.id)
        if lineView.superview == nil {
            linesContainerView.addSubview(lineView)
        }
        if lineNumberView.superview == nil {
            lineNumbersContainerView.addSubview(lineNumberView)
        }
        // Setup the line
        let lineController = getLineController(for: line)
        lineController.lineView = lineView
        lineController.constrainingWidth = isLineWrappingEnabled ? frame.width - leadingLineSpacing : nil
        lineController.willDisplay()
        let lineSize = lineController.preferredSize
        let lineViewFrame = CGRect(x: leadingLineSpacing, y: line.yPosition, width: lineSize.width, height: lineSize.height)
        lineController.lineViewFrame = lineViewFrame
        // Setup the line number
        lineNumberView.text = "\(line.index + 1)"
        lineNumberView.font = theme.font
        lineNumberView.textColor = theme.lineNumberColor
        lineNumberView.frame = CGRect(x: gutterLeadingPadding, y: lineViewFrame.minY, width: lineNumberWidth, height: lineViewFrame.height)
        // Pass back the maximum Y position so the caller can determine if it needs to show more lines.
        maxY = lineView.frame.maxY
        updateSize(of: line, newLineSize: lineController.preferredSize)
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
        let allLineNumberKeys = lineViewReuseQueue.visibleViews.keys
        lineViewReuseQueue.enqueueViews(withKeys: Set(allLineNumberKeys))
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
        gutterSelectionBackgroundView.isHidden = !showSelectedLines || !showLineNumbers || !isEditing
        lineSelectionBackgroundView.isHidden = !showSelectedLines || !isEditing || selectedLength > 0
    }

    private func updateSize(of line: DocumentLineNode, newLineSize: CGSize) {
        let didUpdateHeight = lineManager.setHeight(of: line, to: newLineSize.height)
        if lineWidths[line.id] != newLineSize.width {
            lineWidths[line.id] = newLineSize.width
            if let lineIDTrackingWidth = lineIDTrackingWidth {
                let maximumLineWidth = lineWidths[lineIDTrackingWidth] ?? 0
                if line.id == lineIDTrackingWidth || newLineSize.width > maximumLineWidth {
                    _contentWidth = nil
                }
            } else if !isLineWrappingEnabled {
                _contentWidth = nil
            }
        }
        if didUpdateHeight {
            _contentHeight = nil
        }
    }

    private func invalidateSyntaxHighlighting() {
        for (_, lineController) in lineControllers {
            lineController.invalidateSyntaxHighlighting()
        }
    }

    private func invalidateTypesetting() {
        for (_, lineController) in lineControllers {
            lineController.invalidateTypesetting()
        }
    }

    private func getLineController(for line: DocumentLineNode) -> LineController {
        if let cachedLineController = lineControllers[line.id] {
            return cachedLineController
        } else {
            let lineController = LineController(syntaxHighlighter: syntaxHighlighter, syntaxHighlightQueue: operationQueue, line: line)
            lineController.delegate = self
            lineController.theme = theme
            lineControllers[line.id] = lineController
            return lineController
        }
    }
}

// MARK: - LineControllerDelegate
extension LayoutManager: LineControllerDelegate {
    func string(in lineController: LineController) -> String {
        let line = lineController.line
        let range = NSRange(location: line.location, length: line.data.totalLength)
        return currentDelegate.layoutManager(self, stringIn: range)
    }
}

// MARK: - Memory Management
private extension LayoutManager {
    @objc private func didReceiveMemoryWarning(_ notification: Notification) {
        let allLineIDs = Set(lineControllers.keys)
        let visibleLineIDs = Set(lineViewReuseQueue.visibleViews.keys)
        let lineIDsToRelease = allLineIDs.subtracting(visibleLineIDs)
        for lineID in lineIDsToRelease {
            lineControllers.removeValue(forKey: lineID)
        }
    }
}
