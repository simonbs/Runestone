#if os(iOS)
import UIKit

final class TextInputStringTokenizer: UITextInputStringTokenizer {
    var lineManager: LineManager {
        get {
            return stringTokenizer.lineManager
        }
        set {
            stringTokenizer.lineManager = newValue
        }
    }
    var stringView: StringView {
        get {
            return stringTokenizer.stringView
        }
        set {
            stringTokenizer.stringView = newValue
        }
    }

    private let stringTokenizer: StringTokenizer

    init(
        textInput: UIResponder & UITextInput,
        stringView: StringView,
        lineManager: LineManager,
        lineControllerStorage: LineControllerStorage
    ) {
        self.stringTokenizer = StringTokenizer(stringView: stringView, lineManager: lineManager, lineControllerStorage: lineControllerStorage)
        super.init(textInput: textInput)
    }

    override func isPosition(
        _ position: UITextPosition,
        atBoundary granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> Bool {
        guard let indexedPosition = position as? IndexedPosition else {
            return false
        }
        guard let granularity = StringTokenizer.Granularity(granularity) else {
            return super.isPosition(position, atBoundary: granularity, inDirection: direction)
        }
        let direction = StringTokenizer.Direction(direction)
        return stringTokenizer.isLocation(indexedPosition.index, atBoundary: granularity, inDirection: direction)
    }

    override func isPosition(
        _ position: UITextPosition,
        withinTextUnit granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> Bool {
        return super.isPosition(position, withinTextUnit: granularity, inDirection: direction)
    }

    override func position(
        from position: UITextPosition,
        toBoundary granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        guard let granularity = StringTokenizer.Granularity(granularity) else {
            return super.position(from: position, toBoundary: granularity, inDirection: direction)
        }
        let direction = StringTokenizer.Direction(direction)
        guard let location = stringTokenizer.location(from: indexedPosition.index, toBoundary: granularity, inDirection: direction) else {
            return nil
        }
        return IndexedPosition(index: location)
    }

    override func rangeEnclosingPosition(
        _ position: UITextPosition,
        with granularity: UITextGranularity,
        inDirection direction: UITextDirection
    ) -> UITextRange? {
        return super.rangeEnclosingPosition(position, with: granularity, inDirection: direction)
    }
}

private extension StringTokenizer.Granularity {
    init?(_ granularity: UITextGranularity) {
        switch granularity {
        case .word:
            self = .word
        case .paragraph:
            self = .paragraph
        case .line:
            self = .line
        case .character, .document, .sentence:
            return nil
        @unknown default:
            return nil
        }
    }
}

private extension StringTokenizer.Direction {
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
        return rawValue == UITextStorageDirection.forward.rawValue
        || rawValue == UITextLayoutDirection.right.rawValue
        || rawValue == UITextLayoutDirection.down.rawValue
    }
}
#endif
