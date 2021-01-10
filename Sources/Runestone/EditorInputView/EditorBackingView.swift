//
//  File.swift
//  
//
//  Created by Simon Støvring on 05/01/2021.
//

import UIKit

protocol EditorBackingViewDelegate: AnyObject {
    func editorBackingViewDidInvalidateContentSize(_ view: EditorBackingView)
}

final class EditorBackingView: UIView {
    weak var delegate: EditorBackingViewDelegate?
    var string = NSMutableString() {
        didSet {
            if string != oldValue {
                lineManager.rebuild(from: string)
                isContentSizeInvalid = true
            }
        }
    }
    var selectedTextRange: NSRange?
    var markedTextRange: NSRange?
    var font = UIFont(name: "Menlo-Regular", size: 14)! {
        didSet {
            if font != oldValue {
                lineManager.estimatedLineHeight = font.lineHeight
            }
        }
    }
    var viewport: CGRect = .zero {
        didSet {
            if viewport != oldValue {
                setNeedsDisplay()
            }
        }
    }
    var contentSize: CGSize {
        if isContentSizeInvalid {
            updateContentSize()
            isContentSizeInvalid = false
        }
        return _contentSize
    }

    private let lineManager = LineManager()
    private var textLayers: [DocumentLineNodeID: EditorTextLayer] = [:]
    private var visibleTextLayerIDs: Set<DocumentLineNodeID> = []
    private var isContentSizeInvalid = false
    private var _contentSize: CGSize = .zero

//    private var previousLineContainingCaret: DocumentLine?
//    private var previousLineNumberAtCaret: Int?

    init() {
        super.init(frame: .zero)
        lineManager.delegate = self
        lineManager.estimatedLineHeight = font.lineHeight
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarning(_:)), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        // Core Text has a flipped coordinate system so we flip our context before drawing the text.
        let context = UIGraphicsGetCurrentContext()!
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: rect.height)
        context.scaleBy(x: 1, y: -1)
        drawLines(in: rect, of: context)
        context.restoreGState()
        if isContentSizeInvalid {
            delegate?.editorBackingViewDidInvalidateContentSize(self)
        }
    }

    func insertText(_ text: String) {
        guard let selectedTextRange = selectedTextRange else {
            return
        }
        if selectedTextRange.length > 0 {
            // Replace selected text.
            string.replaceCharacters(in: selectedTextRange, with: text)
            lineManager.removeCharacters(in: selectedTextRange)
            lineManager.insert(text as NSString, at: selectedTextRange.location)
            self.selectedTextRange = NSRange(location: selectedTextRange.location + text.utf16.count, length: 0)
        } else {
            // Insert text at location.
            string.insert(text, at: selectedTextRange.location)
            lineManager.insert(text as NSString, at: selectedTextRange.location)
            self.selectedTextRange = NSRange(location: selectedTextRange.location + text.utf16.count, length: 0)
        }
    }

    func deleteBackward() {
        guard let selectedTextRange = selectedTextRange else {
            return
        }
        if selectedTextRange.length > 0 {
            // Delete selected text.
            string.deleteCharacters(in: selectedTextRange)
            lineManager.removeCharacters(in: selectedTextRange)
            self.selectedTextRange = NSRange(location: selectedTextRange.location, length: 0)
        } else if selectedTextRange.location > 0 {
            // Delete a single character at the location.
            let range = NSRange(location: selectedTextRange.location - 1, length: 1)
            string.deleteCharacters(in: range)
            lineManager.removeCharacters(in: range)
            self.selectedTextRange = NSRange(location: range.location, length: 0)
        }
    }

    func replace(_ range: NSRange, withText text: String) {
        let nsText = text as NSString
        string.replaceCharacters(in: range, with: text)
        lineManager.removeCharacters(in: range)
        lineManager.insert(nsText, at: range.location)
        selectedTextRange = NSRange(location: range.location + text.utf16.count, length: 0)
    }

    func text(in range: NSRange) -> String? {
        if range.location >= 0 && range.upperBound < string.length {
            return string.substring(with: range)
        } else {
            return nil
        }
    }

    func caretRect(atIndex index: Int) -> CGRect {
        // TODO: Make the index passed to careRect(atIndex:) local to the line.
        return .zero
//        let cappedIndex = min(max(index, 0), string.length)
//        if string.length == 0 {
//            previousLineContainingCaret = nil
//            previousLineNumberAtCaret = nil
//            return CGRect(x: 0, y: -font.leading, width: 3, height: font.ascender + abs(font.descender))
////        } else if let line = previousLineContainingCaret, let lineNumber = previousLineNumberAtCaret,
////                  cappedIndex >= line.location && cappedIndex <= line.location + line.totalLength {
////            return textLayerA.caretRect(aIndex: cappedIndex)!
//        } else if let line = lineManager.line(containingCharacterAt: cappedIndex) {
//            previousLineContainingCaret = line
//            previousLineNumberAtCaret = line.lineNumber
//            return textLayerA.caretRect(aIndex: cappedIndex)!
//        } else {
//            fatalError("Cannot find caret rect.")
//        }
    }

    func firstRect(for range: NSRange) -> CGRect {
//        guard let line = lineManager.line(containingCharacterAt: range.location) else {
//            fatalError("Cannot find first rect.")
//        }
        // TODO: Make the input range local to the line.
        return .zero
//        return textLayerA.firstRect(for: range)!
    }

    func closestIndex(to point: CGPoint) -> Int? {
        // TODO: Offset the returned index by the line's start location.
        return nil
//        return textLayerA.closestIndex(to: point)
    }
}

private extension EditorBackingView {
//    private func lineNumber(at location: Int) -> Int? {
//        return lineManager.line(containingCharacterAt: location)?.lineNumber
//    }

    private func drawLines(in rect: CGRect, of context: CGContext) {
        visibleTextLayerIDs = []
        let visibleLines = lineManager.visibleLines(in: viewport)
        for visibleLine in visibleLines {
            draw(visibleLine, in: rect, of: context)
            visibleTextLayerIDs.insert(visibleLine.id)
        }
    }

    private func draw(_ line: DocumentLineNode, in rect: CGRect, of context: CGContext) {
        let textLayer = getTextLayer(forLineId: line.id)
        var height = line.data.frameHeight
        let range = NSRange(location: line.location, length: line.value)
        let lineString = string.substring(with: range) as NSString
        textLayer.setString(lineString)
        let size = textLayer.preferredSize(constrainedToWidth: bounds.width)
        let didUpdateHeight = lineManager.setHeight(size.height, of: line)
        height = size.height
        textLayer.lineIndex = line.index
        // Adjust the y-position to the flipped coordinate system.
        let yPosition = viewport.minY + rect.height - line.yPosition - height
        textLayer.frame = CGRect(x: 0, y: yPosition, width: bounds.width, height: height)
        textLayer.draw(in: context)
        if didUpdateHeight {
            isContentSizeInvalid = true
        }
        if textLayers[line.id] == nil {
            textLayers[line.id] = textLayer
        }
    }

    private func getTextLayer(forLineId lineId: DocumentLineNodeID) -> EditorTextLayer {
        if let textLayer = textLayers[lineId] {
            return textLayer
        } else {
            let textLayer = EditorTextLayer()
            textLayer.font = font
            textLayers[lineId] = textLayer
            return textLayer
        }
    }

    private func updateContentSize() {
        _contentSize = CGSize(width: bounds.width, height: lineManager.contentHeight)
    }

    @objc private func didReceiveMemoryWarning(_ notification: Notification) {
        let allTextLayerIDs = Set(textLayers.keys)
        let unusedTextLayerIDs = allTextLayerIDs.subtracting(visibleTextLayerIDs)
        for unusedTextLayerID in unusedTextLayerIDs {
            textLayers.removeValue(forKey: unusedTextLayerID)
        }
    }
}

extension EditorBackingView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return string.substring(with: NSMakeRange(location, 1))
    }
}
