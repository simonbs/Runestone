import UIKit

final class TextInputStringTokenizer: UITextInputStringTokenizer {
    private let lineManager: LineManager
    private let stringView: StringView

    init(textInput: UIResponder & UITextInput, lineManager: LineManager, stringView: StringView) {
        self.lineManager = lineManager
        self.stringView = stringView
        super.init(textInput: textInput)
    }

    override func isPosition(_ position: UITextPosition, atBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool {
        guard let indexedPosition = position as? IndexedPosition else {
            return super.isPosition(position, atBoundary: granularity, inDirection: direction)
        }
        if (granularity == .line || granularity == .paragraph), let line = lineManager.line(containingCharacterAt: indexedPosition.index) {
            let localIndex = indexedPosition.index - line.location
            if isBackward(direction) {
                return localIndex == 0
            } else {
                return localIndex == line.data.length
            }
        } else if granularity == .word, isCustomWordBoundry(at: indexedPosition.index) {
            return true
        } else {
            return super.isPosition(position, atBoundary: granularity, inDirection: map(direction))
        }
    }

    override func isPosition(_ position: UITextPosition,
                             withinTextUnit granularity: UITextGranularity,
                             inDirection direction: UITextDirection) -> Bool {
        return super.isPosition(position, withinTextUnit: granularity, inDirection: map(direction))
    }

    override func position(from position: UITextPosition,
                           toBoundary granularity: UITextGranularity,
                           inDirection direction: UITextDirection) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return super.position(from: position, toBoundary: granularity, inDirection: direction)
        }
        if (granularity == .line || granularity == .paragraph), let line = lineManager.line(containingCharacterAt: indexedPosition.index) {
            if isBackward(direction) {
                return IndexedPosition(index: line.location)
            } else {
                return IndexedPosition(index: line.location + line.data.length)
            }
        } else {
            return super.position(from: position, toBoundary: granularity, inDirection: map(direction))
        }
    }

    override func rangeEnclosingPosition(_ position: UITextPosition,
                                         with granularity: UITextGranularity,
                                         inDirection direction: UITextDirection) -> UITextRange? {
        return super.rangeEnclosingPosition(position, with: granularity, inDirection: map(direction))
    }
}

private extension TextInputStringTokenizer {
    private func isCustomWordBoundry(at location: Int) -> Bool {
        guard let character = stringView.character(at: location) else {
            return false
        }
        let wordBoundryCharacterSet: CharacterSet = .punctuationCharacters
        return character.unicodeScalars.allSatisfy { wordBoundryCharacterSet.contains($0) }
    }

    private func map(_ direction: UITextDirection) -> UITextDirection {
        if direction.rawValue == UITextLayoutDirection.left.rawValue {
            return .storage(.backward)
        } else if direction.rawValue == UITextLayoutDirection.right.rawValue {
            return .storage(.forward)
        } else {
            return direction
        }
    }

    private func isBackward(_ direction: UITextDirection) -> Bool {
        return direction.rawValue == UITextStorageDirection.backward.rawValue || direction.rawValue == UITextLayoutDirection.left.rawValue
    }

    private func isForward(_ direction: UITextDirection) -> Bool {
        return direction.rawValue == UITextStorageDirection.forward.rawValue || direction.rawValue == UITextLayoutDirection.right.rawValue
    }
}

