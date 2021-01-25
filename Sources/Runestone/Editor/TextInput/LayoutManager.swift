//
//  LayoutManager.swift
//  
//
//  Created by Simon Støvring on 25/01/2021.
//

import UIKit

protocol LayoutManagerDelegate: AnyObject {
    func layoutManager(_ layoutManager: LayoutManager, stringIn range: NSRange) -> String
    func layoutManager(_ layoutManager: LayoutManager, shouldInsertViewIntoViewHierarchy view: UIView)
    func layoutManagerDidInvalidateContentSize(_ layoutManager: LayoutManager)
    func lengthOfString(in layoutManager: LayoutManager) -> Int
}

final class LayoutManager {
    weak var delegate: LayoutManagerDelegate?
    var frame: CGRect = .zero
    var viewport: CGRect = .zero
    var contentSize: CGSize {
        if let contentSize = _contentSize {
            return contentSize
        } else {
            let contentSize = CGSize(width: frame.width, height: lineManager.contentHeight)
            _contentSize = contentSize
            return contentSize
        }
    }
    var font: UIFont?
    var textColor: UIColor?
    var backgroundColor: UIColor?
    var lineManager: LineManager

    private let syntaxHighlightController: SyntaxHighlightController
    private let syntaxHighlightQueue = OperationQueue()
    private var queuedLineViews: Set<LineView> = []
    private var visibleLineViews: [DocumentLineNodeID: LineView] = [:]
    private var textRenderers: [DocumentLineNodeID: TextRenderer] = [:]
    private var _contentSize: CGSize?
    private var currentDelegate: LayoutManagerDelegate {
        if let delegate = delegate {
            return delegate
        } else {
            fatalError("Delegate unavailable")
        }
    }

    init(lineManager: LineManager, syntaxHighlightController: SyntaxHighlightController) {
        self.lineManager = lineManager
        self.syntaxHighlightController = syntaxHighlightController
        self.syntaxHighlightQueue.name = "Runestone.SyntaxHighlightQueue"
        self.syntaxHighlightQueue.qualityOfService = .userInitiated
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarning(_:)), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    func layoutLines() {
        let oldVisibleLineIds = Set(visibleLineViews.keys)
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
        enqueueLineViews(withIDs: disappearedLineIDs)
        if _contentSize == nil {
            delegate?.layoutManagerDidInvalidateContentSize(self)
        }
    }

    func invalidate() {
        _contentSize = nil
    }

    func removeLine(withID lineID: DocumentLineNodeID) {
        textRenderers.removeValue(forKey: lineID)
    }

    func updateLineViews(showing lines: Set<DocumentLineNode>) {
       for line in lines {
           if let textRenderer = textRenderers[line.id] {
               syntaxHighlightController.removedCachedAttributes(for: line.id)
               textRenderer.invalidate()
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
        return CGRect(x: localCaretRect.minX, y: globalYPosition, width: localCaretRect.width, height: localCaretRect.height)
    }

    func firstRect(for range: NSRange) -> CGRect? {
        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        let textRenderer = textRenderers[line.id]!
        let localRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
        return textRenderer.firstRect(for: localRange)
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

    private func closestIndex(to point: CGPoint, in textRenderer: TextRenderer, showing line: DocumentLineNode) -> Int? {
        let localPoint = CGPoint(x: point.x, y: point.y - textRenderer.frame.minY)
        if let index = textRenderer.closestIndex(to: localPoint) {
            if index >= line.data.length && index <= line.data.totalLength && line != lineManager.lastLine {
                return line.location + line.data.length
            } else {
                return line.location + index
            }
        } else {
            return nil
        }
    }
}

// MARK: - Drawing
extension LayoutManager {
    private func show(_ line: DocumentLineNode, maxY: inout CGFloat) {
        syntaxHighlightController.prepare()
        let lineView = dequeueLineView(withID: line.id)
        if lineView.superview == nil {
            currentDelegate.layoutManager(self, shouldInsertViewIntoViewHierarchy: lineView)
        }
        let textRenderer = getTextRenderer(for: line)
        prepare(textRenderer, toShow: line)
        lineView.textRenderer = textRenderer
        lineView.frame = CGRect(x: 0, y: line.yPosition, width: frame.width, height: textRenderer.preferredHeight)
        lineView.backgroundColor = backgroundColor
        textRenderer.syntaxHighlight(line.data.byteRange, inLineWithID: line.id)
        maxY = lineView.frame.maxY
    }

    private func enqueueLineViews(withIDs lineIDs: Set<DocumentLineNodeID>) {
        for lineID in lineIDs {
            if let lineView = visibleLineViews.removeValue(forKey: lineID) {
                lineView.removeFromSuperview()
                queuedLineViews.insert(lineView)
            }
        }
    }

    private func dequeueLineView(withID lineID: DocumentLineNodeID) -> LineView {
        if let lineView = visibleLineViews[lineID] {
            return lineView
        } else if !queuedLineViews.isEmpty {
            let lineView = queuedLineViews.removeFirst()
            visibleLineViews[lineID] = lineView
            return lineView
        } else {
            let lineView = LineView()
            visibleLineViews[lineID] = lineView
            return lineView
        }
    }

    private func getTextRenderer(for line: DocumentLineNode) -> TextRenderer {
        if let cachedTextRenderer = textRenderers[line.id] {
            return cachedTextRenderer
        } else {
            let textRenderer = TextRenderer(syntaxHighlightController: syntaxHighlightController, syntaxHighlightQueue: syntaxHighlightQueue)
            textRenderer.delegate = self
            prepare(textRenderer, toShow: line)
            textRenderers[line.id] = textRenderer
            return textRenderer
        }
    }

    private func prepare(_ textRenderer: TextRenderer, toShow line: DocumentLineNode) {
        textRenderer.line = line
        textRenderer.lineWidth = frame.width
        textRenderer.font = font
        textRenderer.textColor = textColor
        textRenderer.prepare()
        let lineHeight = ceil(textRenderer.preferredHeight)
        let didUpdateHeight = lineManager.setHeight(of: line, to: lineHeight)
        if didUpdateHeight {
            _contentSize = nil
        }
    }
}

// MARK: - TextRendererDelegate
extension LayoutManager: TextRendererDelegate {
    func textRenderer(_ textRenderer: TextRenderer, stringIn line: DocumentLineNode) -> String {
        let range = NSRange(location: line.location, length: line.value)
        return currentDelegate.layoutManager(self, stringIn: range)
    }

    func textRendererDidUpdateSyntaxHighlighting(_ textRenderer: TextRenderer) {
        if let lineID = textRenderer.line?.id {
            let lineView = visibleLineViews[lineID]
            lineView?.setNeedsDisplay()
        }
    }
}

// MARK: - Memory Management
private extension LayoutManager {
    @objc private func didReceiveMemoryWarning(_ notification: Notification) {
        syntaxHighlightController.clearCache()
        let allLineIDs = Set(textRenderers.keys)
        let visibleLineIDs = Set(visibleLineViews.keys)
        let lineIDsToRelease = allLineIDs.subtracting(visibleLineIDs)
        for lineID in lineIDsToRelease {
            textRenderers.removeValue(forKey: lineID)
        }
    }
}
