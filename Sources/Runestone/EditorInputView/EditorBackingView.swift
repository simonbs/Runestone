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
        let range = selectedTextRange ?? NSRange(location: string.length, length: 0)
        replace(range, withText: text)
    }

    func deleteBackward() {
        if let selectedTextRange = selectedTextRange {
            string.replaceCharacters(in: selectedTextRange, with: "")
        } else if string.length > 0 {
            let range = NSMakeRange(string.length - 1, 1)
            replace(range, withText: "")
        }
    }

    func replace(_ range: NSRange, withText text: String) {
        let nsText = text as NSString
        string.replaceCharacters(in: range, with: text)
        lineManager.removeCharacters(in: range)
        lineManager.insert(nsText, at: range.location)
    }

    func text(in range: NSRange) -> String? {
        if range.location >= 0 && range.upperBound < string.length {
            return string.substring(with: range)
        } else {
            return nil
        }
    }

    func caretRect(atIndex index: Int) -> CGRect {
        if string.length == 0 {
            previousLineContainingCaret = nil
            previousLineNumberAtCaret = nil
            return CGRect(x: 0, y: -font.leading, width: 3, height: font.ascender + abs(font.descender))
        } else if let line = previousLineContainingCaret, index >= line.location && index <= line.location + line.totalLength, let lineNumber = previousLineNumberAtCaret {
            print("Reuse line: \(lineNumber)")
            return CGRect(x: 0, y: 0, width: 3, height: font.ascender + abs(font.descender))
        } else if let line = lineManager.line(containingCharacterAt: index) {
            previousLineContainingCaret = line
            previousLineNumberAtCaret = line.lineNumber
            print(line.lineNumber)
            return CGRect(x: 0, y: 0, width: 3, height: font.ascender + abs(font.descender))
        } else {
            fatalError("Cannot find caret rect.")
        }
    }
}

extension EditorBackingView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return string.substring(with: NSMakeRange(location, 1))
    }
}
