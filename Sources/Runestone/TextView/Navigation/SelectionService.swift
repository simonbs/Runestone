#if os(macOS)
import Foundation

final class SelectionService {
    var stringView: StringView
    var lineManager: LineManager
    var lineControllerStorage: LineControllerStorage

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
    private var lineNavigationLocationService: LineNavigationLocationFactory {
        LineNavigationLocationFactory(lineManager: lineManager, lineControllerStorage: lineControllerStorage)
    }

    init(stringView: StringView, lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
    }

    func range(moving range: NSRange, by granularity: TextGranularity, inDirection direction: TextDirection) -> NSRange {
        if range.length == 0 {
            selectionOrigin = range.location
        }
        let anchoringDirection = anchoringDirection(moving: range, inDirection: direction)
        switch (granularity, anchoringDirection) {
        case (.character, .backward):
            let upperBound = characterNavigationLocationService.location(movingFrom: range.upperBound, inDirection: direction)
            return range.withUpperBound(upperBound)
        case (.character, .forward):
            let lowerBound = characterNavigationLocationService.location(movingFrom: range.lowerBound, inDirection: direction)
            return range.withLowerBound(lowerBound)
        case (.word, .backward):
            let upperBound = wordNavigationLocationService.location(movingFrom: range.upperBound, inDirection: direction)
            return range.withUpperBound(upperBound)
        case (.word, .forward):
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
        if range.length == 0 {
            selectionOrigin = range.location
        }
        return range
    }

    func rangeByStartDraggingSelection(from location: Int) -> NSRange {
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
}

private extension SelectionService {
    private func anchoringDirection(moving range: NSRange, inDirection direction: TextDirection) -> TextDirection {
        if range.upperBound == selectionOrigin {
            return .forward
        } else {
            return .backward
        }
    }
}

private extension NSRange {
    func withLowerBound(_ newLowerBound: Int) -> NSRange {
        let newLength = upperBound - newLowerBound
        return NSRange(location: newLowerBound, length: newLength)
    }

    func withUpperBound(_ newUpperBound: Int) -> NSRange {
        let newLength = newUpperBound - lowerBound
        return NSRange(location: lowerBound, length: newLength)
    }
}
#endif
