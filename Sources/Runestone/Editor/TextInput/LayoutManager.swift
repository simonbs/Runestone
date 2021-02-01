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
                invalidateAllLines()
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
                invalidateAllLines()
            }
        }
    }
    var isEditing = false {
        didSet {
            if isEditing != oldValue {
                updateShownViews()
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
    private let syntaxHighlightController: SyntaxHighlightController
    private var textRenderers: [DocumentLineNodeID: TextRenderer] = [:]
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

    init(lineManager: LineManager, syntaxHighlightController: SyntaxHighlightController, operationQueue: OperationQueue) {
        self.lineManager = lineManager
        self.syntaxHighlightController = syntaxHighlightController
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
        syntaxHighlightController.prepare()
        layoutGutter()
        layoutSelection()
        let oldVisibleLineIds = Set(lineViewReuseQueue.visibleViews.keys)
        var nextLine = lineManager.line(containingYOffset: viewport.minY)
        var appearedLineIDs: Set<DocumentLineNodeID> = []
        var maxY = viewport.minY
        while let line = nextLine, maxY < viewport.maxY {
            appearedLineIDs.insert(line.id)
            show(line, maxY: &maxY)
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
        textRenderers.removeValue(forKey: lineID)
    }

    func invalidateAndPrepare(_ lines: Set<DocumentLineNode>) {
        for line in lines {
            if let textRenderer = textRenderers[line.id] {
                textRenderer.documentRange = NSRange(location: line.location, length: line.data.totalLength)
                textRenderer.documentByteRange = line.data.byteRange
                textRenderer.invalidate()
                textRenderer.prepareToDraw()
            }
        }
    }

    func invalidateAllLines() {
        let allTextRenderers = textRenderers.values
        for textRenderer in allTextRenderers {
            textRenderer.invalidate()
        }
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
}

// MARK: - UITextInput
extension LayoutManager {
    func caretRect(at location: Int) -> CGRect? {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        let textRenderer = getTextRenderer(for: line)
        let localLocation = location - line.location
        let localCaretRect = textRenderer.caretRect(atIndex: localLocation)
        let globalYPosition = line.yPosition + localCaretRect.minY
        let globalRect = CGRect(x: localCaretRect.minX, y: globalYPosition, width: localCaretRect.width, height: localCaretRect.height)
        return globalRect.offsetBy(dx: leadingLineSpacing, dy: 0)
    }

    func firstRect(for range: NSRange) -> CGRect {
        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        let textRenderer = textRenderers[line.id]!
        let localRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
        let firstRect = textRenderer.firstRect(for: localRange)
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
            let textRenderer = getTextRenderer(for: line)
            let lineStartLocation = line.location
            let lineEndLocation = lineStartLocation + line.data.totalLength
            let localRangeLocation = max(range.location, lineStartLocation) - lineStartLocation
            let localRangeLength = min(range.location + range.length, lineEndLocation) - lineStartLocation - localRangeLocation
            let localRange = NSRange(location: localRangeLocation, length: localRangeLength)
            let rendererSelectionRects = textRenderer.selectionRects(in: localRange)
            let textSelectionRects: [TextSelectionRect] = rendererSelectionRects.map { rendererSelectionRect in
                let y = line.yPosition + rendererSelectionRect.rect.minY
                var screenRect = CGRect(x: rendererSelectionRect.rect.minX, y: y, width: rendererSelectionRect.rect.width, height: rendererSelectionRect.rect.height)
                let startLocation = lineStartLocation + rendererSelectionRect.range.location
                let endLocation = startLocation + rendererSelectionRect.range.length
                let containsStart = range.location >= startLocation && range.location <= endLocation
                let containsEnd = range.location + range.length >= startLocation && range.location + range.length <= endLocation
                screenRect.origin.x += leadingLineSpacing
                if endLocation < range.location + range.length {
                    screenRect.size.width = frame.width - screenRect.minX
                }
                return TextSelectionRect(rect: screenRect, writingDirection: .leftToRight, containsStart: containsStart, containsEnd: containsEnd)
            }
            selectionRects.append(contentsOf: textSelectionRects)
        }
        return selectionRects.ensuringYAxisAlignment()
    }

    func closestIndex(to point: CGPoint) -> Int? {
        if let line = lineManager.line(containingYOffset: point.y), let textRenderer = textRenderers[line.id] {
            return closestIndex(to: point, in: textRenderer, showing: line)
        } else if point.y <= 0 {
            let firstLine = lineManager.firstLine
            if let textRenderer = textRenderers[firstLine.id] {
                return closestIndex(to: point, in: textRenderer, showing: firstLine)
            } else {
                return 0
            }
        } else {
            let lastLine = lineManager.lastLine
            if point.y >= lastLine.yPosition, let textRenderer = textRenderers[lastLine.id] {
                return closestIndex(to: point, in: textRenderer, showing: lastLine)
            } else {
                return currentDelegate.lengthOfString(in: self)
            }
        }
    }

    private func closestIndex(to point: CGPoint, in textRenderer: TextRenderer, showing line: DocumentLineNode) -> Int {
        let localPoint = CGPoint(x: point.x - leadingLineSpacing, y: point.y - textRenderer.frame.minY)
        let index = textRenderer.closestIndex(to: localPoint)
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
            let startTextRenderer = getTextRenderer(for: startLine)
            let endTextRenderer = getTextRenderer(for: endLine)
            let yPos = startTextRenderer.frame.minY
            let height = endTextRenderer.frame.maxY - startTextRenderer.frame.minY
            selectedRect = CGRect(x: 0, y: yPos, width: frame.width, height: height)
        } else {
            let line = lineManager.line(containingCharacterAt: startLocation)!
            let textRenderer = getTextRenderer(for: line)
            selectedRect = CGRect(x: 0, y: textRenderer.frame.minY, width: frame.width, height: textRenderer.frame.height)
        }
        gutterSelectionBackgroundView.frame = CGRect(x: 0, y: selectedRect.minY, width: gutterWidth, height: selectedRect.height)
        lineSelectionBackgroundView.frame = CGRect(x: viewport.minX + gutterWidth, y: selectedRect.minY, width: frame.width - gutterWidth, height: selectedRect.height)
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
}

// MARK: - Drawing
extension LayoutManager {
    private func show(_ line: DocumentLineNode, maxY: inout CGFloat) {
        let lineView = lineViewReuseQueue.dequeueView(forKey: line.id)
        let lineNumberView = lineNumberLabelReuseQueue.dequeueView(forKey: line.id)
        // Ensure views are added to the view hiearchy
        if lineView.superview == nil {
            linesContainerView.addSubview(lineView)
        }
        if lineNumberView.superview == nil {
            lineNumbersContainerView.addSubview(lineNumberView)
        }
        // Setup the line
        let lineYPosition = line.yPosition
        let textRenderer = getTextRenderer(for: line)
        prepare(textRenderer, toDraw: line)
        let lineSize = textRenderer.preferredLineSize
        lineView.textRenderer = textRenderer
        lineView.frame = CGRect(x: leadingLineSpacing, y: lineYPosition, width: lineSize.width, height: lineSize.height)
        lineView.setNeedsDisplay()
        // Setup the line number
        lineNumberView.text = "\(line.index + 1)"
        lineNumberView.textColor = theme.lineNumberColor
        lineNumberView.font = theme.font
        lineNumberView.frame = CGRect(x: gutterLeadingPadding, y: lineYPosition, width: lineNumberWidth, height: lineSize.height)
        // Start highlighting the line
        textRenderer.syntaxHighlight()
        // Pass back the maximum Y position so the caller can determine if it needs to show more lines.
        maxY = lineView.frame.maxY
    }

    private func getTextRenderer(for line: DocumentLineNode) -> TextRenderer {
        if let cachedTextRenderer = textRenderers[line.id] {
            return cachedTextRenderer
        } else {
            let textRenderer = TextRenderer(syntaxHighlightController: syntaxHighlightController, syntaxHighlightQueue: operationQueue)
            textRenderer.delegate = self
            textRenderer.lineID = line.id
            prepare(textRenderer, toDraw: line)
            textRenderers[line.id] = textRenderer
            return textRenderer
        }
    }

    private func prepare(_ textRenderer: TextRenderer, toDraw line: DocumentLineNode) {
        textRenderer.lineID = line.id
        textRenderer.documentRange = NSRange(location: line.location, length: line.data.totalLength)
        textRenderer.documentByteRange = line.data.byteRange
        textRenderer.theme = theme
        textRenderer.invisibleCharacterConfiguration = invisibleCharacterConfiguration
        if isLineWrappingEnabled {
            textRenderer.constrainingLineWidth = frame.width - leadingLineSpacing
        } else {
            textRenderer.constrainingLineWidth = nil
        }
        textRenderer.prepareToDraw()
        let didUpdateHeight = lineManager.setHeight(of: line, to: textRenderer.preferredLineSize.height)
        if lineWidths[line.id] != textRenderer.preferredLineSize.width {
            lineWidths[line.id] = textRenderer.preferredLineSize.width
            if let lineIDTrackingWidth = lineIDTrackingWidth {
                let maximumLineWidth = lineWidths[lineIDTrackingWidth] ?? 0
                if line.id == lineIDTrackingWidth || textRenderer.preferredLineSize.width > maximumLineWidth {
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
}

// MARK: - TextRendererDelegate
extension LayoutManager: TextRendererDelegate {
    func textRenderer(_ textRenderer: TextRenderer, stringIn range: NSRange) -> String {
        return currentDelegate.layoutManager(self, stringIn: range)
    }

    func textRendererDidUpdateSyntaxHighlighting(_ textRenderer: TextRenderer) {
        if let lineID = textRenderer.lineID {
            let lineView = lineViewReuseQueue.visibleViews[lineID]
            lineView?.setNeedsDisplay()
        }
    }
}

// MARK: - Memory Management
private extension LayoutManager {
    @objc private func didReceiveMemoryWarning(_ notification: Notification) {
        let allLineIDs = Set(textRenderers.keys)
        let visibleLineIDs = Set(lineViewReuseQueue.visibleViews.keys)
        let lineIDsToRelease = allLineIDs.subtracting(visibleLineIDs)
        for lineID in lineIDsToRelease {
            textRenderers.removeValue(forKey: lineID)
        }
    }
}
