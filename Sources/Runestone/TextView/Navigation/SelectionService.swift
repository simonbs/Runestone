#if os(macOS)
import Foundation

final class SelectionService {
    var stringView: StringView
    var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                lineNavigationLocationService.lineManager = lineManager
            }
        }
    }

    private struct BracketPair {
        let opening: String
        let closing: String

        func component(inDirection direction: TextDirection) -> String {
            switch direction {
            case .backward:
                return opening
            case .forward:
                return closing
            }
        }
    }

    private let lineControllerStorage: LineControllerStorage
    private var anchoringDirection: TextDirection?
    private var selectionOrigin: Int?

    private var stringTokenizer: StringTokenizer {
        StringTokenizer(stringView: stringView, lineManager: lineManager, lineControllerStorage: lineControllerStorage)
    }
    private var characterNavigationLocationService: CharacterNavigationLocationFactory {
        CharacterNavigationLocationFactory(stringView: stringView)
    }
    private var wordNavigationLocationService: WordNavigationLocationFactory {
        WordNavigationLocationFactory(stringTokenizer: stringTokenizer)
    }
    private let lineNavigationLocationService: StatefulLineNavigationLocationFactory

    init(stringView: StringView, lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.lineNavigationLocationService = StatefulLineNavigationLocationFactory(
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }

    func range(moving range: NSRange, by granularity: TextGranularity, inDirection direction: TextDirection) -> NSRange {
        if range.length == 0 {
            selectionOrigin = range.location
            lineNavigationLocationService.reset()
        }
        let anchoringDirection = anchoringDirection(moving: range, inDirection: direction)
        switch (granularity, anchoringDirection) {
        case (.character, .backward):
            lineNavigationLocationService.reset()
            let upperBound = characterNavigationLocationService.location(movingFrom: range.upperBound, inDirection: direction)
            return range.withUpperBound(upperBound)
        case (.character, .forward):
            lineNavigationLocationService.reset()
            let lowerBound = characterNavigationLocationService.location(movingFrom: range.lowerBound, inDirection: direction)
            return range.withLowerBound(lowerBound)
        case (.word, .backward):
            lineNavigationLocationService.reset()
            let upperBound = wordNavigationLocationService.location(movingFrom: range.upperBound, inDirection: direction)
            return range.withUpperBound(upperBound)
        case (.word, .forward):
            lineNavigationLocationService.reset()
            let lowerBound = wordNavigationLocationService.location(movingFrom: range.lowerBound, inDirection: direction)
            return range.withLowerBound(lowerBound)
        case (.line, .backward):
            let upperBound = lineNavigationLocationService.location(movingFrom: range.upperBound, inDirection: direction)
            return range.withUpperBound(upperBound)
        case (.line, .forward):
            let lowerBound = lineNavigationLocationService.location(movingFrom: range.lowerBound, inDirection: direction)
            return range.withLowerBound(lowerBound)
        }
    }

    func range(moving range: NSRange, toBoundary boundary: TextBoundary, inDirection direction: TextDirection) -> NSRange {
        lineNavigationLocationService.reset()
        if range.length == 0 {
            selectionOrigin = range.location
        }
        let anchoringDirection = anchoringDirection(moving: range, inDirection: direction)
        switch anchoringDirection {
        case .backward:
            if let upperBound = stringTokenizer.location(from: range.upperBound, toBoundary: boundary, inDirection: direction) {
                return range.withUpperBound(upperBound)
            } else {
                return range
            }
        case .forward:
            if let lowerBound = stringTokenizer.location(from: range.lowerBound, toBoundary: boundary, inDirection: direction) {
                return range.withLowerBound(lowerBound)
            } else {
                return range
            }
        }
    }

    func rangeByStartDraggingSelection(from location: Int) -> NSRange {
        lineNavigationLocationService.reset()
        let range = NSRange(location: location, length: 0)
        selectionOrigin = location
        return range
    }

    func rangeByExtendingDraggedSelection(to location: Int) -> NSRange {
        guard let selectionOrigin else {
            return NSRange(location: location, length: 0)
        }
        let lowerBound = min(selectionOrigin, location)
        let upperBound = max(selectionOrigin, location)
        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }

    func rangeBySelectingWord(at location: Int) -> NSRange {
        guard location >= 0 && location < stringView.string.length else {
            return NSRange(location: location, length: 0)
        }
        let character = stringView.string.character(at: location)
        let substringRange = stringView.string.customRangeOfComposedCharacterSequence(at: location)
        let substring = stringView.string.substring(with: substringRange)
        let selectableSymbols = [Symbol.carriageReturnLineFeed, Symbol.carriageReturn, Symbol.lineFeed]
        let bracketPairs = [
            BracketPair(opening: "(", closing: ")"),
            BracketPair(opening: "{", closing: "}"),
            BracketPair(opening: "[", closing: "]")
        ]
        if let scalar = Unicode.Scalar(character), CharacterSet.whitespaces.contains(scalar) {
            return rangeOfWhitespace(matching: character, at: location)
        } else if CharacterSet.alphanumerics.containsAllCharacters(of: substring) {
            let lowerBound = stringTokenizer.location(from: location, toBoundary: .word, inDirection: .backward) ?? location
            let upperBound = stringTokenizer.location(from: location, toBoundary: .word, inDirection: .forward) ?? location
            return NSRange(location: lowerBound, length: upperBound - lowerBound)
        } else if let selectableSymbol = selectableSymbols.first(where: { $0 == substring }) {
            return NSRange(location: location, length: selectableSymbol.count)
        } else if let bracketPair = bracketPairs.first(where: { $0.opening == substring }) {
            return range(enclosing: bracketPair, inDirection: .forward, startingAt: location)
        } else if let bracketPair = bracketPairs.first(where: { $0.closing == substring }) {
            return range(enclosing: bracketPair, inDirection: .backward, startingAt: location)
        } else {
            return NSRange(location: location, length: 1)
        }
    }

    func rangeBySelectingLine(at location: Int) -> NSRange {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return NSRange(location: location, length: 0)
        }
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let lineLocalLocation = location - line.location
        guard let lineFragment = lineController.lineFragmentNode(containingCharacterAt: lineLocalLocation) else {
            return NSRange(location: location, length: 0)
        }
        guard let range = lineFragment.data.lineFragment?.range else {
            return NSRange(location: location, length: 0)
        }
        return NSRange(location: line.location + range.location, length: range.length)
    }
}

private extension SelectionService {
    private func anchoringDirection(moving range: NSRange, inDirection direction: TextDirection) -> TextDirection {
        if range.length == 0 {
            return direction.opposite
        } else if range.upperBound == selectionOrigin {
            return .forward
        } else {
            return .backward
        }
    }

    private func rangeOfWhitespace(matching character: unichar, at location: Int) -> NSRange {
        var lowerBound = location
        var upperBound = location + 1
        while lowerBound > 0 && lowerBound < stringView.string.length && stringView.string.character(at: lowerBound - 1) == character {
            lowerBound -= 1
        }
        while upperBound >= 0 && upperBound < stringView.string.length && stringView.string.character(at: upperBound) == character {
            upperBound += 1
        }
        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }

    private func range(enclosing characterPair: BracketPair, inDirection direction: TextDirection, startingAt location: Int) -> NSRange {
        func advanceLocation(_ location: Int) -> Int {
            switch direction {
            case .forward:
                return location + 1
            case .backward:
                return location - 1
            }
        }
        // Keep track of how many unclosed brackets we have. Whenever we reach zero we have found our end location.
        var unclosedBracketsCount = 1
        var endLocation = advanceLocation(location)
        // In this case an "opening" component can actually be a closing component, e.g. "}", if that's what the user double clicked. That closing bracket "opens" our selection and we need to find the needle component, e.g. "{".
        let openingComponent = characterPair.component(inDirection: direction.opposite)
        let needleComponent = characterPair.component(inDirection: direction)
        while endLocation > 0 && endLocation < stringView.string.length && unclosedBracketsCount > 0 {
            let characterRange = NSRange(location: endLocation, length: 1)
            let substring = stringView.string.substring(with: characterRange)
            if substring == openingComponent {
                unclosedBracketsCount += 1
            }
            if substring == needleComponent {
                unclosedBracketsCount -= 1
            }
            endLocation = advanceLocation(endLocation)
        }
        var lowerBound = min(location, endLocation)
        var upperBound = max(location, endLocation)
        // Offset the range by one if we are searching backwards as we want to select the character on the input location.
        if direction == .backward {
            lowerBound += 1
            upperBound += 1
        }
        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }
}

private extension NSRange {
    func withLowerBound(_ lowerBound: Int) -> NSRange {
        let newLength = upperBound - lowerBound
        return NSRange(location: lowerBound, length: newLength)
    }

    func withUpperBound(_ upperBound: Int) -> NSRange {
        let newLength = upperBound - lowerBound
        return NSRange(location: lowerBound, length: newLength)
    }
}
#endif
