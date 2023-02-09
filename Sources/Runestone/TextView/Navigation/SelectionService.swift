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
