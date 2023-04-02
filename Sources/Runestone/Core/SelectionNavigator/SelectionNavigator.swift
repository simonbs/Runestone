import Combine
import Foundation

final class SelectionNavigator {
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

    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let lineControllerStorage: LineControllerStorage
    private let stringTokenizer: StringTokenizer
    private let characterNavigationLocationFactory: CharacterNavigationLocationFactory
    private let wordNavigationLocationFactory: WordNavigationLocationFactory
    private let lineNavigationLocationFactory: LineNavigationLocationFactory
    private var selectionOrigin: Int?

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        lineControllerStorage: LineControllerStorage,
        stringTokenizer: StringTokenizer,
        characterNavigationLocationFactory: CharacterNavigationLocationFactory,
        wordNavigationLocationFactory: WordNavigationLocationFactory,
        lineNavigationLocationFactory: LineNavigationLocationFactory
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.selectedRange = selectedRange
        self.lineControllerStorage = lineControllerStorage
        self.stringTokenizer = stringTokenizer
        self.characterNavigationLocationFactory = characterNavigationLocationFactory
        self.wordNavigationLocationFactory = wordNavigationLocationFactory
        self.lineNavigationLocationFactory = lineNavigationLocationFactory
    }

    func moveLeftAndModifySelection() {
        lineNavigationLocationFactory.reset()
        selectedRange.value = range(moving: selectedRange.value, by: .character, inDirection: .backward)
    }

    func moveRightAndModifySelection() {
        lineNavigationLocationFactory.reset()
        selectedRange.value = range(moving: selectedRange.value, by: .character, inDirection: .forward)
    }

    func moveUpAndModifySelection() {
        selectedRange.value = range(moving: selectedRange.value, by: .line, inDirection: .backward)
    }

    func moveDownAndModifySelection() {
        selectedRange.value = range(moving: selectedRange.value, by: .line, inDirection: .forward)
    }

    func moveWordLeftAndModifySelection() {
        lineNavigationLocationFactory.reset()
        selectedRange.value = range(moving: selectedRange.value, by: .word, inDirection: .backward)
    }

    func moveWordRightAndModifySelection() {
        lineNavigationLocationFactory.reset()
        selectedRange.value = range(moving: selectedRange.value, by: .word, inDirection: .forward)
    }

    func moveToBeginningOfLineAndModifySelection() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .line, inDirection: .backward)
    }

    func moveToEndOfLineAndModifySelection() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .line, inDirection: .forward)
    }

    func moveToBeginningOfParagraphAndModifySelection() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .paragraph, inDirection: .backward)
    }

    func moveToEndOfParagraphAndModifySelection() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .paragraph, inDirection: .forward)
    }

    func moveToBeginningOfDocumentAndModifySelection() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .document, inDirection: .backward)
    }

    func moveToEndOfDocumentAndModifySelection() {
        lineNavigationLocationFactory.reset()
        move(toBoundary: .document, inDirection: .forward)
    }

    func startDraggingSelection(from location: Int) {
        selectedRange.value = rangeByStartDraggingSelection(from: location)
    }

    func extendDraggedSelection(to location: Int) {
        selectedRange.value = rangeByExtendingDraggedSelection(to: location)
    }

    func selectWord(at location: Int) {
        selectedRange.value = rangeBySelectingWord(at: location)
    }

    func selectLine(at location: Int) {
        selectedRange.value = rangeBySelectingLine(at: location)
    }
}

private extension SelectionNavigator {
    private func move(toBoundary boundary: TextBoundary, inDirection direction: TextDirection) {
        selectedRange.value = range(moving: selectedRange.value, toBoundary: boundary, inDirection: direction)
    }

    private func range(moving range: NSRange, by granularity: TextGranularity, inDirection direction: TextDirection) -> NSRange {
        if range.length == 0 {
            selectionOrigin = range.location
            lineNavigationLocationFactory.reset()
        }
        let anchoringDirection = anchoringDirection(moving: range, inDirection: direction)
        switch (granularity, anchoringDirection) {
        case (.character, .backward):
            lineNavigationLocationFactory.reset()
            let upperBound = characterNavigationLocationFactory.location(movingFrom: range.upperBound, inDirection: direction)
            return range.withUpperBound(upperBound)
        case (.character, .forward):
            lineNavigationLocationFactory.reset()
            let lowerBound = characterNavigationLocationFactory.location(movingFrom: range.lowerBound, inDirection: direction)
            return range.withLowerBound(lowerBound)
        case (.word, .backward):
            lineNavigationLocationFactory.reset()
            let upperBound = wordNavigationLocationFactory.location(movingFrom: range.upperBound, inDirection: direction)
            return range.withUpperBound(upperBound)
        case (.word, .forward):
            lineNavigationLocationFactory.reset()
            let lowerBound = wordNavigationLocationFactory.location(movingFrom: range.lowerBound, inDirection: direction)
            return range.withLowerBound(lowerBound)
        case (.line, .backward):
            let upperBound = lineNavigationLocationFactory.location(movingFrom: range.upperBound, byLineCount: 1, inDirection: direction)
            return range.withUpperBound(upperBound)
        case (.line, .forward):
            let lowerBound = lineNavigationLocationFactory.location(movingFrom: range.lowerBound, byLineCount: 1, inDirection: direction)
            return range.withLowerBound(lowerBound)
        }
    }

    private func range(moving range: NSRange, toBoundary boundary: TextBoundary, inDirection direction: TextDirection) -> NSRange {
        lineNavigationLocationFactory.reset()
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

    private func rangeByStartDraggingSelection(from location: Int) -> NSRange {
        lineNavigationLocationFactory.reset()
        let range = NSRange(location: location, length: 0)
        selectionOrigin = location
        return range
    }

    private func rangeByExtendingDraggedSelection(to location: Int) -> NSRange {
        guard let selectionOrigin else {
            return NSRange(location: location, length: 0)
        }
        let lowerBound = min(selectionOrigin, location)
        let upperBound = max(selectionOrigin, location)
        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }

    private func rangeBySelectingWord(at location: Int) -> NSRange {
        guard location >= 0 && location < stringView.value.string.length else {
            return NSRange(location: location, length: 0)
        }
        let character = stringView.value.string.character(at: location)
        let substringRange = stringView.value.string.customRangeOfComposedCharacterSequence(at: location)
        let substring = stringView.value.string.substring(with: substringRange)
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

    private func rangeBySelectingLine(at location: Int) -> NSRange {
        guard let line = lineManager.value.line(containingCharacterAt: location) else {
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
        while lowerBound > 0 && lowerBound < stringView.value.string.length && stringView.value.string.character(at: lowerBound - 1) == character {
            lowerBound -= 1
        }
        while upperBound >= 0 && upperBound < stringView.value.string.length && stringView.value.string.character(at: upperBound) == character {
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
        while endLocation > 0 && endLocation < stringView.value.string.length && unclosedBracketsCount > 0 {
            let characterRange = NSRange(location: endLocation, length: 1)
            let substring = stringView.value.string.substring(with: characterRange)
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
