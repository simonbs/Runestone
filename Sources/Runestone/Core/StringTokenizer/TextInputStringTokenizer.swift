#if os(iOS)
import UIKit

final class TextInputStringTokenizer: UITextInputStringTokenizer {
    private let stringTokenizer: StringTokenizing

    init(textInput: UIResponder & UITextInput, stringTokenizer: StringTokenizing) {
        self.stringTokenizer = stringTokenizer
        super.init(textInput: textInput)
    }

    override func isPosition(
        _ position: UITextPosition,
        atBoundary granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> Bool {
        guard let position = position as? RunestoneUITextPosition else {
            return false
        }
        guard let boundary = TextBoundary(granularity) else {
            return super.isPosition(position, atBoundary: granularity, inDirection: direction)
        }
        let direction = TextDirection(direction)
        return stringTokenizer.isLocation(position.location, atBoundary: boundary, inDirection: direction)
    }

    override func isPosition(
        _ position: UITextPosition,
        withinTextUnit granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> Bool {
        super.isPosition(position, withinTextUnit: granularity, inDirection: direction)
    }

    override func position(
        from position: UITextPosition,
        toBoundary granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> UITextPosition? {
        guard let position = position as? RunestoneUITextPosition else {
            return nil
        }
        guard let boundary = TextBoundary(granularity) else {
            return super.position(from: position, toBoundary: granularity, inDirection: direction)
        }
        let direction = TextDirection(direction)
        guard let location = stringTokenizer.location(
            from: position.location, 
            toBoundary: boundary, 
            inDirection: direction
        ) else {
            return nil
        }
        return RunestoneUITextPosition(location)
    }

    override func rangeEnclosingPosition(
        _ position: UITextPosition,
        with granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> UITextRange? {
        super.rangeEnclosingPosition(position, with: granularity, inDirection: direction)
    }
}

private extension TextBoundary {
    init?(_ granularity: UITextGranularity) {
        switch granularity {
        case .word:
            self = .word
        case .paragraph:
            self = .paragraph
        case .line:
            self = .line
        case .document:
            self = .document
        case .character, .sentence:
            return nil
        @unknown default:
            return nil
        }
    }
}

private extension TextDirection {
    init(_ direction: UITextDirection) {
        if direction.isForward {
            self = .forward
        } else {
            self = .backward
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
#endif
