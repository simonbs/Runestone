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
                let oldEntireRange = NSRange(location: 0, length: oldValue.length)
                lineManager.removeCharacters(in: oldEntireRange)
                lineManager.insert(string, at: 0)
                isContentSizeInvalid = true
            }
        }
    }
    var selectedTextRange: NSRange?
    var markedTextRange: NSRange?
    var font = UIFont(name: "Menlo-Regular", size: 14)!
    var contentSize: CGSize {
        if isContentSizeInvalid {
            updateContentSize()
            isContentSizeInvalid = false
        }
        return _contentSize
    }

    private let lineManager = LineManager()
    private var textLayers: [LineFrameNodeID: EditorTextLayer] = [:]
    private var visibleTextLayers: [EditorTextLayer] = []
    private var layersPendingStringUpdate: Set<EditorTextLayer> = []
    private var isContentSizeInvalid = false
    private var _contentSize: CGSize = .zero

//    private var previousLineContainingCaret: DocumentLine?
//    private var previousLineNumberAtCaret: Int?

    init() {
        super.init(frame: .zero)
        lineManager.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    func layoutLines(in rect: CGRect) {
        let visibleLines = lineManager.visibleLines(in: rect)
        var isContentHeightValid = true
        var newVisibleTextLayers: [EditorTextLayer] = []
        for visibleLine in visibleLines {
            let textLayer = getTextLayer(forLineId: visibleLine.lineFrame.id)
            var height = visibleLine.lineFrame.value
            if layersPendingStringUpdate.contains(textLayer) {
                let range = NSRange(location: visibleLine.documentLine.location, length: visibleLine.documentLine.value)
                let lineString = string.substring(with: range) as NSString
                textLayer.setString(lineString)
                textLayer.setNeedsDisplay()
                let size = textLayer.preferredSize(constrainedToWidth: bounds.width)
                let didUpdateHeight = lineManager.setHeight(size.height, of: visibleLine.lineFrame)
                height = size.height
                if didUpdateHeight {
                    isContentHeightValid = false
                }
                layersPendingStringUpdate.remove(textLayer)
            }
            textLayer.lineIndex = visibleLine.documentLine.index
            if textLayer.superlayer == nil {
                layer.addSublayer(textLayer)
            }
            textLayer.frame = CGRect(x: 0, y: visibleLine.lineFrame.location, width: bounds.width, height: height)
            newVisibleTextLayers.append(textLayer)
        }
        for textLayer in visibleTextLayers {
            if !newVisibleTextLayers.contains(textLayer) {
                textLayer.removeFromSuperlayer()
            }
        }
        visibleTextLayers = newVisibleTextLayers
        if !isContentHeightValid {
            isContentSizeInvalid = true
            delegate?.editorBackingViewDidInvalidateContentSize(self)
        }
    }
}

private extension EditorBackingView {
//    private func lineNumber(at location: Int) -> Int? {
//        return lineManager.line(containingCharacterAt: location)?.lineNumber
//    }

    private func getTextLayer(forLineId lineId: LineFrameNodeID) -> EditorTextLayer {
        if let textLayer = textLayers[lineId] {
            return textLayer
        } else {
            let textLayer = EditorTextLayer()
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.font = font
            textLayers[lineId] = textLayer
            layersPendingStringUpdate.insert(textLayer)
            return textLayer
        }
    }

    func updateContentSize() {
        _contentSize = CGSize(width: bounds.width, height: lineManager.contentHeight)
    }
}

extension EditorBackingView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return string.substring(with: NSMakeRange(location, 1))
    }
}
