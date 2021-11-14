//
//  ReplacementStringParser.swift
//  
//
//  Created by Simon on 14/11/2021.
//

import Foundation

final class ReplacementStringParser {
    private let string: String
    private var isInEscapeSequence = false
    private var isCollectingPlaceholder = false
    private var collectedString = ""
    private var components: [ParsedReplacementString.Component] = []
    private let numberCharacterSet = CharacterSet(charactersIn: "1234567890")

    init(string: String) {
        self.string = string
    }

    func parse() -> ParsedReplacementString {
        var index = string.startIndex
        while index < string.endIndex {
            let character = string[index]
            if character == "\\" {
                takeBackslash()
            } else if character == "$" {
                takeDollarSign()
            } else if isCollectingPlaceholder {
                takeCharacterWhileCollectingPlaceholder(character: character)
            } else {
                collectedString += String(character)
            }
            index = string.index(after: index)
        }
        finalizeComponents()
        return ParsedReplacementString(components: components)
    }
}

private extension ReplacementStringParser {
    private func takeBackslash() {
        if isCollectingPlaceholder, let placeholderValue = placeholderValue(from: collectedString) {
            components.append(.placeholder(placeholderValue))
            collectedString = ""
        }
        isInEscapeSequence = true
        isCollectingPlaceholder = false
        collectedString += "\\"
    }

    private func takeDollarSign() {
        if isInEscapeSequence {
            // We're escaping the dollar sign so we'll remove the backslash from the collected string.
            collectedString.removeLast()
            collectedString += "$"
            isCollectingPlaceholder = false
            isInEscapeSequence = false
        } else if isCollectingPlaceholder {
            // We're already collecting another placeholder so we'll wrap that up and continue with a new one.
            if let placeholderValue = placeholderValue(from: collectedString) {
                components.append(.placeholder(placeholderValue))
                collectedString = ""
            }
        } else {
            // Wrap up the text we were collecting and start collecting a placeholder
            if !collectedString.isEmpty {
                components.append(.text(collectedString))
                collectedString = ""
            }
            isCollectingPlaceholder = true
        }
    }

    private func takeCharacterWhileCollectingPlaceholder(character: Character) {
        let unicodeScalars = character.unicodeScalars
        if unicodeScalars.count == 1 && numberCharacterSet.contains(unicodeScalars[unicodeScalars.startIndex]) {
            collectedString += String(character)
        } else {
            if let placeholderValue = placeholderValue(from: collectedString) {
                components.append(.placeholder(placeholderValue))
                collectedString = ""
            }
            isCollectingPlaceholder = false
            collectedString += String(character)
        }
    }

    private func finalizeComponents() {
        guard !collectedString.isEmpty else {
            return
        }
        if isCollectingPlaceholder, let placeholderValue = placeholderValue(from: collectedString) {
            components.append(.placeholder(placeholderValue))
        } else {
            components.append(.text(collectedString))
        }
    }

    private func placeholderValue(from string: String) -> Int? {
        if !string.isEmpty {
            return Int(string)
        } else {
            return nil
        }
    }
}
