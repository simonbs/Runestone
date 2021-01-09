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
                frameStore.reset()
            }
        }
    }
    var selectedTextRange: NSRange?
    var markedTextRange: NSRange?
    var font = UIFont(name: "Menlo-Regular", size: 14)! {
        didSet {
            if font != oldValue {
                frameStore.estimatedLineHeight = font.ascender + font.descender
            }
        }
    }
    var contentSize: CGSize {
        return frameStore.contentSize
    }

    private let lineManager = LineManager()
    private let frameStore = EditorTextLayerFrameStore()
    private var textLayers: [UUID: EditorTextLayer] = [:]
    private var visibleTextLayers: [EditorTextLayer] = []
    private var layersPendingStringUpdate: Set<EditorTextLayer> = []

//    private var previousLineContainingCaret: DocumentLine?
//    private var previousLineNumberAtCaret: Int?

    init() {
        super.init(frame: .zero)
        lineManager.delegate = self
        frameStore.delegate = self
        frameStore.estimatedLineHeight = font.ascender + font.descender
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        frameStore.width = bounds.width
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
//        let lineIndices = visibleLineIndices(in: rect)
//        var newVisibleTextLayers: [EditorTextLayer] = []
//        var isContentHeightValid = true
//        for lineIndex in lineIndices {
//            let line = lineManager.line(atIndex: lineIndex)
//            let textLayer = getTextLayer(forLineId: line.id)
//            if layersPendingStringUpdate.contains(textLayer) {
//                let range = NSRange(location: line.location, length: line.context.totalLength)
//                let lineString = string.substring(with: range) as NSString
//                textLayer.setString(lineString)
//                textLayer.setNeedsDisplay()
//                let size = textLayer.preferredSize(constrainedToWidth: bounds.width)
//                let didUpdateHeight = frameStore.setHeight(to: size.height, forLineAt: lineIndex)
//                if didUpdateHeight {
//                    isContentHeightValid = false
//                }
//                layersPendingStringUpdate.remove(textLayer)
//            }
//            textLayer.lineIndex = lineIndex
//            newVisibleTextLayers.append(textLayer)
//        }
//        for textLayer in visibleTextLayers {
//            if !newVisibleTextLayers.contains(textLayer) {
//                textLayer.removeFromSuperlayer()
//            }
//        }
//        for textLayer in newVisibleTextLayers {
//            if textLayer.superlayer == nil {
//                layer.addSublayer(textLayer)
//            }
//            textLayer.frame = frameStore.frameForLine(at: textLayer.lineIndex)
//        }
//        visibleTextLayers = newVisibleTextLayers
//        if !isContentHeightValid {
//            delegate?.editorBackingViewDidInvalidateContentSize(self)
//        }
    }
}

private extension EditorBackingView {
//    private func lineNumber(at location: Int) -> Int? {
//        return lineManager.line(containingCharacterAt: location)?.lineNumber
//    }

    private func visibleLineIndices(in rect: CGRect) -> IndexSet {
        var indices = IndexSet()
        for lineIndex in 0 ..< lineManager.lineCount {
            let frame = frameStore.frameForLine(at: lineIndex)
            if frame.intersects(rect) {
                indices.insert(lineIndex)
            } else if !indices.isEmpty {
                // The item's frame is outside the rect and we've already found at least one item in the section
                // and since items are ordered sequentially, we don't have to look any further.
                break
            }
        }
        return indices
    }

    private func getTextLayer(forLineId lineId: UUID) -> EditorTextLayer {
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
}

extension EditorBackingView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return string.substring(with: NSMakeRange(location, 1))
    }
}

extension EditorBackingView: EditorTextLayerFrameStoreDelegate {
    func editorTextLayerFrameStore(_ frameStore: EditorTextLayerFrameStore, estimatedHeightForItemAt index: Int) -> CGFloat {
        return font.ascender + font.descender
    }

    func numberOfLines(in frameStore: EditorTextLayerFrameStore) -> Int {
        return lineManager.lineCount
    }
}
