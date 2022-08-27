import UIKit

final class TextInputStringTokenizer: UITextInputStringTokenizer {
    private let stringView: StringView
    private let lineManager: LineManager
    private let lineControllerStorage: LineControllerStorage

    init(textInput: UIResponder & UITextInput, stringView: StringView, lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.lineManager = lineManager
        self.stringView = stringView
        self.lineControllerStorage = lineControllerStorage
        super.init(textInput: textInput)
    }

    override func isPosition(_ position: UITextPosition, atBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool {
        guard let indexedPosition = position as? IndexedPosition else {
            return super.isPosition(position, atBoundary: granularity, inDirection: direction)
        }
        if granularity == .line || granularity == .paragraph {
            if let location = lineBoundaryLocation(forLineContainingCharacterAt: indexedPosition.index, inDirection: direction) {
                return indexedPosition.index == location
            } else {
                return false
            }
        } else if granularity == .paragraph {
            if let location = paragraphBoundaryLocation(forLineContainingCharacterAt: indexedPosition.index, inDirection: direction) {
                return indexedPosition.index == location
            } else {
                return false
            }
        } else if granularity == .word, isCustomWordBoundry(at: indexedPosition.index) {
            return true
        } else {
            return super.isPosition(position, atBoundary: granularity, inDirection: direction)
        }
    }

    override func isPosition(_ position: UITextPosition,
                             withinTextUnit granularity: UITextGranularity,
                             inDirection direction: UITextDirection) -> Bool {
        return super.isPosition(position, withinTextUnit: granularity, inDirection: direction)
    }

    override func position(from position: UITextPosition,
                           toBoundary granularity: UITextGranularity,
                           inDirection direction: UITextDirection) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return super.position(from: position, toBoundary: granularity, inDirection: direction)
        }
        if granularity == .line || granularity == .paragraph {
            return lineBoundaryLocation(forLineContainingCharacterAt: indexedPosition.index, inDirection: direction).map(IndexedPosition.init)
        } else if granularity == .paragraph {
            return paragraphBoundaryLocation(forLineContainingCharacterAt: indexedPosition.index, inDirection: direction).map(IndexedPosition.init)
        } else {
            return super.position(from: position, toBoundary: granularity, inDirection: direction)
        }
    }

    override func rangeEnclosingPosition(_ position: UITextPosition,
                                         with granularity: UITextGranularity,
                                         inDirection direction: UITextDirection) -> UITextRange? {
        return super.rangeEnclosingPosition(position, with: granularity, inDirection: direction)
    }
}

private extension TextInputStringTokenizer {
    private func lineBoundaryLocation(forLineContainingCharacterAt sourceLocation: Int, inDirection direction: UITextDirection) -> Int? {
        guard let line = lineManager.line(containingCharacterAt: sourceLocation) else {
            return nil
        }
        guard let lineController = lineControllerStorage[line.id] else {
            return nil
        }
        let lineLocalLocation = sourceLocation - line.location
        let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: lineLocalLocation)
        guard let lineFragment = lineFragmentNode.data.lineFragment else {
            return nil
        }
        if isBackward(direction) {
            return lineFragment.range.lowerBound
        } else if sourceLocation == lineFragment.range.lowerBound {
            return lineFragmentNode.previous.data.lineFragment?.range.upperBound
        } else {
            return lineFragment.range.upperBound
        }
    }

    private func paragraphBoundaryLocation(forLineContainingCharacterAt sourceLocation: Int, inDirection direction: UITextDirection) -> Int? {
        guard let line = lineManager.line(containingCharacterAt: sourceLocation) else {
            return nil
        }
        if isBackward(direction) {
            return line.location
        } else {
            return line.location + line.data.length
        }
    }

    private func isCustomWordBoundry(at location: Int) -> Bool {
        guard let character = stringView.character(at: location) else {
            return false
        }
        let wordBoundryCharacterSet: CharacterSet = .punctuationCharacters
        return character.unicodeScalars.allSatisfy { wordBoundryCharacterSet.contains($0) }
    }

    private func isBackward(_ direction: UITextDirection) -> Bool {
        return direction.rawValue == UITextStorageDirection.backward.rawValue || direction.rawValue == UITextLayoutDirection.left.rawValue
    }
}
