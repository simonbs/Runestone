//
//  TextInputStringTokenizer.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import UIKit

final class TextInputStringTokenizer: UITextInputStringTokenizer {
    private let lineManager: LineManager

    init(textInput: UIResponder & UITextInput, lineManager: LineManager) {
        self.lineManager = lineManager
        super.init(textInput: textInput)
    }

    override func isPosition(_ position: UITextPosition, atBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool {
        guard let indexedPosition = position as? IndexedPosition else {
            return super.isPosition(position, atBoundary: granularity, inDirection: direction)
        }
        if granularity == .line, let line = lineManager.line(containingCharacterAt: indexedPosition.index) {
            let localIndex = indexedPosition.index - line.location
            return localIndex == line.data.totalLength
        } else if granularity == .word {
            return true
        } else {
            return super.isPosition(position, atBoundary: granularity, inDirection: direction)
        }
    }
}
