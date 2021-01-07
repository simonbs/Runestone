//
//  File.swift
//  
//
//  Created by Simon Støvring on 05/01/2021.
//

import UIKit

final class EditorBackingView: UIView {
    var isEditing = false
    let string = NSMutableString()
    var selectedTextRange: NSRange?
    var markedTextRange: NSRange?
    var font = UIFont(name: "Menlo-Regular", size: 14)!

    private let textLayerA = EditorTextLayer()
    private let textLayerB = EditorTextLayer()
    private let lineManager = LineManager()
    private var previousLineContainingCaret: DocumentLine?
    private var previousLineNumberAtCaret: Int?

    init() {
        super.init(frame: .zero)
        lineManager.delegate = self
        textLayerA.contentsScale = UIScreen.main.scale
        textLayerB.contentsScale = UIScreen.main.scale
        textLayerA.font = UIFont(name: "Menlo-Regular", size: 14)
        textLayerB.font = UIFont(name: "Menlo-Regular", size: 14)
        textLayerA.setString("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec facilisis commodo orci. Maecenas eget diam sapien. Nullam posuere bibendum convallis. Cras nisi felis, placerat ac venenatis eget, tristique et orci. Sed in mi mattis augue interdum tristique sit amet nec libero. Fusce nulla dui, ullamcorper et est ac, finibus feugiat quam. Donec erat justo, dignissim eget volutpat sit amet, suscipit vel felis. Ut rhoncus massa in hendrerit pulvinar. Nam vulputate porttitor orci eu scelerisque. Fusce eget diam ut nisi interdum lacinia feugiat id dui. In tempus, tortor eu accumsan dictum, lorem leo finibus dolor, hendrerit congue est metus sit amet neque. Suspendisse condimentum ac ligula quis scelerisque.")
        textLayerB.setString("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec facilisis commodo orci. Maecenas eget diam sapien. Nullam posuere bibendum convallis. Cras nisi felis, placerat ac venenatis eget, tristique et orci. Sed in mi mattis augue interdum tristique sit amet nec libero. Fusce nulla dui, ullamcorper et est ac, finibus feugiat quam. Donec erat justo, dignissim eget volutpat sit amet, suscipit vel felis. Ut rhoncus massa in hendrerit pulvinar. Nam vulputate porttitor orci eu scelerisque. Fusce eget diam ut nisi interdum lacinia feugiat id dui. In tempus, tortor eu accumsan dictum, lorem leo finibus dolor, hendrerit congue est metus sit amet neque. Suspendisse condimentum ac ligula quis scelerisque.")
        textLayerA.setNeedsDisplay()
        textLayerB.setNeedsDisplay()
        layer.addSublayer(textLayerA)
        layer.addSublayer(textLayerB)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let sizeA = textLayerA.preferredSize(constrainedToWidth: bounds.size.width)
        let sizeB = textLayerB.preferredSize(constrainedToWidth: bounds.size.width)
        textLayerA.frame = CGRect(x: 0, y: 0, width: sizeA.width, height: sizeA.height)
        textLayerB.frame = CGRect(x: 0, y: textLayerA.frame.maxY, width: sizeB.width, height: sizeB.height)
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
        let cappedIndex = min(max(index, 0), string.length)
        if string.length == 0 {
            previousLineContainingCaret = nil
            previousLineNumberAtCaret = nil
            return CGRect(x: 0, y: -font.leading, width: 3, height: font.ascender + abs(font.descender))
//        } else if let line = previousLineContainingCaret, let lineNumber = previousLineNumberAtCaret,
//                  cappedIndex >= line.location && cappedIndex <= line.location + line.totalLength {
//            return textLayerA.caretRect(aIndex: cappedIndex)!
        } else if let line = lineManager.line(containingCharacterAt: cappedIndex) {
            previousLineContainingCaret = line
            previousLineNumberAtCaret = line.lineNumber
            return textLayerA.caretRect(aIndex: cappedIndex)!
        } else {
            fatalError("Cannot find caret rect.")
        }
    }

    func firstRect(for range: NSRange) -> CGRect {
        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        // TODO: Make the input range local to the line.
        return textLayerA.firstRect(for: range)!
    }

    func closestIndex(to point: CGPoint) -> Int? {
        // TODO: Offset the returned index by the line's start location.
        return textLayerA.closestIndex(to: point)
    }
}

extension EditorBackingView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return string.substring(with: NSMakeRange(location, 1))
    }
}
