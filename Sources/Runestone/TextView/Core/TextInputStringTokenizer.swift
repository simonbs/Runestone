import UIKit

final class TextInputStringTokenizer: UITextInputStringTokenizer {
    var lineManager: LineManager
    var stringView: StringView
    // Used to ensure we can workaround bug where multi-stage input, like when entering Korean text
    // does not work properly. If we do not treat navigation between word boundies as a special case then
    // navigating with Shift + Option + Arrow Keys followed by Shift + Arrow Keys will not work correctly.
    var didCallPositionFromPositionToWordBoundary = false

    private let lineControllerStorage: LineControllerStorage
    private var newlineCharacters: [Character] {
        [Symbol.Character.lineFeed, Symbol.Character.carriageReturn, Symbol.Character.carriageReturnLineFeed]
    }

    init(textInput: UIResponder & UITextInput, stringView: StringView, lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.lineManager = lineManager
        self.stringView = stringView
        self.lineControllerStorage = lineControllerStorage
        super.init(textInput: textInput)
    }

    override func isPosition(_ position: UITextPosition, atBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool {
        if granularity == .line {
            return isPosition(position, atLineBoundaryInDirection: direction)
        } else if granularity == .paragraph {
            return isPosition(position, atParagraphBoundaryInDirection: direction)
        } else if granularity == .word {
            return isPosition(position, atWordBoundaryInDirection: direction)
        } else {
            return super.isPosition(position, atBoundary: granularity, inDirection: direction)
        }
    }

    override func position(from position: UITextPosition,
                           toBoundary granularity: UITextGranularity,
                           inDirection direction: UITextDirection) -> UITextPosition? {
        if granularity == .line {
            return self.position(from: position, toLineBoundaryInDirection: direction)
        } else if granularity == .paragraph {
            return self.position(from: position, toParagraphBoundaryInDirection: direction)
        } else if granularity == .word {
            return self.position(from: position, toWordBoundaryInDirection: direction)
        } else {
            return super.position(from: position, toBoundary: granularity, inDirection: direction)
        }
    }
}

// MARK: - Lines
private extension TextInputStringTokenizer {
    private func isPosition(_ position: UITextPosition, atLineBoundaryInDirection direction: UITextDirection) -> Bool {
        guard let indexedPosition = position as? IndexedPosition else {
            return false
        }
        let location = indexedPosition.index
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return false
        }
        let lineLocation = line.location
        let lineLocalLocation = location - lineLocation
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        guard lineLocalLocation >= 0 && lineLocalLocation <= line.data.totalLength else {
            return false
        }
        guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: lineLocalLocation) else {
            return false
        }
        if direction.isForward {
            let isLastLineFragment = lineFragmentNode.index == lineController.numberOfLineFragments - 1
            if isLastLineFragment {
                return location == lineLocation + lineFragmentNode.location + lineFragmentNode.value - line.data.delimiterLength
            } else {
                return location == lineLocation + lineFragmentNode.location + lineFragmentNode.value
            }
        } else {
            return location == lineLocation + lineFragmentNode.location
        }
    }

    private func position(from position: UITextPosition, toLineBoundaryInDirection direction: UITextDirection) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        let location = indexedPosition.index
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let lineLocation = line.location
        let lineLocalLocation = location - lineLocation
        guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: lineLocalLocation) else {
            return nil
        }
        if direction.isForward {
            if location == stringView.string.length {
                return position
            } else {
                let lineFragmentRangeUpperBound = lineFragmentNode.location + lineFragmentNode.value
                let preferredLocation = lineLocation + lineFragmentRangeUpperBound
                let lineEndLocation = lineLocation + line.data.totalLength
                if preferredLocation == lineEndLocation {
                    // Navigate to end of line but before the delimiter (\n etc.)
                    return IndexedPosition(index: preferredLocation - line.data.delimiterLength)
                } else {
                    // Navigate to the end of the line but before the last character. This is a hack that avoids an issue where the caret is placed on the next line. The approach seems to be similar to what Textastic is doing.
                    let lastCharacterRange = stringView.string.customRangeOfComposedCharacterSequence(at: lineFragmentRangeUpperBound)
                    return IndexedPosition(index: lineLocation + lineFragmentRangeUpperBound - lastCharacterRange.length)
                }
            }
        } else if location == 0 {
            return position
        } else {
            return IndexedPosition(index: lineLocation + lineFragmentNode.location)
        }
    }
}

// MARK: - Paragraphs
private extension TextInputStringTokenizer {
    private func isPosition(_ position: UITextPosition, atParagraphBoundaryInDirection direction: UITextDirection) -> Bool {
        // I can't seem to make Ctrl+A, Ctrl+E, Cmd+Left, and Cmd+Right work properly if this function returns anything but false.
        // I've tried various ways of determining the paragraph boundary but UIKit doesn't seem to be happy with anything I come up with ultimately leading to incorrect keyboard navigation. I haven't yet found any drawbacks to returning false in all cases.
        false
    }

    private func position(from position: UITextPosition, toParagraphBoundaryInDirection direction: UITextDirection) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        let location = indexedPosition.index
        if direction.isForward {
            if location == stringView.string.length {
                return position
            } else {
                var currentIndex = location
                while currentIndex < stringView.string.length {
                    guard let currentCharacter = stringView.character(at: currentIndex) else {
                        break
                    }
                    if newlineCharacters.contains(currentCharacter) {
                        break
                    }
                    currentIndex += 1
                }
                return IndexedPosition(index: currentIndex)
            }
        } else {
            if location == 0 {
                return position
            } else {
                var currentIndex = location - 1
                while currentIndex > 0 {
                    guard let currentCharacter = stringView.character(at: currentIndex) else {
                        break
                    }
                    if newlineCharacters.contains(currentCharacter) {
                        currentIndex += 1
                        break
                    }
                    currentIndex -= 1
                }
                return IndexedPosition(index: currentIndex)
            }
        }
    }
}

// MARK: - Words
private extension TextInputStringTokenizer {
    private func isPosition(_ position: UITextPosition, atWordBoundaryInDirection direction: UITextDirection) -> Bool {
        guard let indexedPosition = position as? IndexedPosition else {
            return false
        }
        let location = indexedPosition.index
        let alphanumerics = CharacterSet.alphanumerics
        if direction.isForward {
            if location == 0 {
                return false
            } else if let previousCharacter = stringView.character(at: location - 1) {
                if location == stringView.string.length {
                    return alphanumerics.contains(previousCharacter)
                } else if let character = stringView.character(at: location) {
                    return alphanumerics.contains(previousCharacter) && !alphanumerics.contains(character)
                } else {
                    return false
                }
            } else {
                return false
            }
        } else {
            if location == stringView.string.length {
                return false
            } else if let character = stringView.character(at: location) {
                if location == 0 {
                    return alphanumerics.contains(character)
                } else if let previousCharacter = stringView.character(at: location - 1) {
                    return alphanumerics.contains(character) && !alphanumerics.contains(previousCharacter)
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func position(from position: UITextPosition, toWordBoundaryInDirection direction: UITextDirection) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        didCallPositionFromPositionToWordBoundary = true
        let location = indexedPosition.index
        let alphanumerics = CharacterSet.alphanumerics
        if direction.isForward {
            if location == stringView.string.length {
                return position
            } else if let referenceCharacter = stringView.character(at: location) {
                let isReferenceCharacterAlphanumeric = alphanumerics.contains(referenceCharacter)
                var currentIndex = location + 1
                while currentIndex < stringView.string.length {
                    guard let currentCharacter = stringView.character(at: currentIndex) else {
                        break
                    }
                    let isCurrentCharacterAlphanumeric = alphanumerics.contains(currentCharacter)
                    if isReferenceCharacterAlphanumeric != isCurrentCharacterAlphanumeric {
                        break
                    }
                    currentIndex += 1
                }
                return IndexedPosition(index: currentIndex)
            } else {
                return nil
            }
        } else {
            if location == 0 {
                return position
            } else if let referenceCharacter = stringView.character(at: location - 1) {
                let isReferenceCharacterAlphanumeric = alphanumerics.contains(referenceCharacter)
                var currentIndex = location - 1
                while currentIndex > 0 {
                    guard let currentCharacter = stringView.character(at: currentIndex) else {
                        break
                    }
                    let isCurrentCharacterAlphanumeric = alphanumerics.contains(currentCharacter)
                    if isReferenceCharacterAlphanumeric != isCurrentCharacterAlphanumeric {
                        currentIndex += 1
                        break
                    }
                    currentIndex -= 1
                }
                return IndexedPosition(index: currentIndex)
            } else {
                return nil
            }
        }
    }
}

private extension UITextDirection {
    var isForward: Bool {
        rawValue == UITextStorageDirection.forward.rawValue
        || rawValue == UITextLayoutDirection.right.rawValue
        || rawValue == UITextLayoutDirection.down.rawValue
    }
}

private extension CharacterSet {
    func contains(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(contains(_:))
    }
}
