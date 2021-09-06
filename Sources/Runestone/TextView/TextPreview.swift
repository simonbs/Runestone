//
//  TextPreview.swift
//  
//
//  Created by Simon on 31/08/2021.
//

import Foundation

public protocol TextPreviewDelegate: AnyObject {
    func textPreviewDidUpdateAttributedString(_ provider: TextPreview)
}

public final class TextPreview {
    public weak var delegate: TextPreviewDelegate?
    public private(set) var attributedString: NSAttributedString?
    public private(set) var localLocation: Int?

    private let lineController: LineController
    private let locationInLine: Int

    init(lineController: LineController, locationInLine: Int) {
        self.lineController = lineController
        self.locationInLine = locationInLine
        lineController.addObserver(self)
    }

    public func prepare() {
        updateAttributedString()
    }

    public func cancelSyntaxHighlighting() {
        lineController.cancelSyntaxHighlighting()
    }
}

private extension TextPreview {
    private func updateAttributedString() {
        lineController.prepareToDisplayString(toLocation: locationInLine, syntaxHighlightAsynchronously: true)
        let range = rangeOfLineFragmentNodes(surroundingCharacterAt: locationInLine)
        localLocation = locationInLine - range.location
        attributedString = lineController.attributedString?.attributedSubstring(from: range)
    }

    private func rangeOfLineFragmentNodes(surroundingCharacterAt location: Int) -> NSRange {
        let startLocation: Int
        let endLocation: Int
        let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: location)
        let index = lineFragmentNode.index
        if index > 0 {
            let previousLineFragmentNode = lineController.lineFragmentNode(atIndex: index - 1)
            startLocation = previousLineFragmentNode.location
        } else {
            startLocation = lineFragmentNode.location
        }
        if index < lineController.numberOfLineFragments - 1 {
            let nextLineFragmentNode = lineController.lineFragmentNode(atIndex: index + 1)
            endLocation = nextLineFragmentNode.location + nextLineFragmentNode.value
        } else if index == 0 {
            // Small optimization to avoid re-computing lineFragmentNode.location when there is no previous line.
            endLocation = startLocation + lineFragmentNode.value
        } else {
            endLocation = lineFragmentNode.location + lineFragmentNode.value
        }
        let length = endLocation - startLocation
        return NSRange(location: startLocation, length: length)
    }
}

extension TextPreview: LineControllerAttributedStringObserver {
    func lineControllerDidUpdateAttributedString(_ lineController: LineController) {
        updateAttributedString()
        delegate?.textPreviewDidUpdateAttributedString(self)
    }
}
