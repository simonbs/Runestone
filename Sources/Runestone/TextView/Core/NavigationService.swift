import Foundation

final class NavigationService {
    enum Granularity {
        case character
        case line
        case word
    }

    var stringView: StringView
    var lineManager: LineManager {
        get {
            return lineNavigationService.lineManager
        }
        set {
            lineNavigationService.lineManager = newValue
        }
    }
    var lineControllerStorage: LineControllerStorage {
        get {
            return lineNavigationService.lineControllerStorage
        }
        set {
            lineNavigationService.lineControllerStorage = newValue
        }
    }

    private struct LineMovementOperation {
        let sourceLocation: Int
        let offset: Int
    }

    private let lineNavigationService: LineNavigationService
    private let stringTokenizer: StringTokenizer
    private var previousLineMovementOperation: LineMovementOperation?

    init(stringView: StringView, lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.stringView = stringView
        self.lineNavigationService = LineNavigationService(lineManager: lineManager, lineControllerStorage: lineControllerStorage)
        self.stringTokenizer = StringTokenizer(stringView: stringView, lineManager: lineManager, lineControllerStorage: lineControllerStorage)
    }

    func location(movingFrom sourceLocation: Int, by granularity: Granularity, offset: Int) -> Int {
        switch granularity {
        case .character:
            previousLineMovementOperation = nil
            return location(movingFrom: sourceLocation, byCharacterCount: offset)
        case .word:
            previousLineMovementOperation = nil
            return location(movingFrom: sourceLocation, byWordCount: offset)
        case .line:
            return location(movingFrom: sourceLocation, byLineCount: offset)
        }
    }

    func resetPreviousLineMovementOperation() {
        previousLineMovementOperation = nil
    }
}

private extension NavigationService {
    private func location(movingFrom sourceLocation: Int, byCharacterCount offset: Int) -> Int {
        let naiveNewLocation = sourceLocation + offset
        guard naiveNewLocation >= 0 && naiveNewLocation <= stringView.string.length else {
            return sourceLocation
        }
        guard naiveNewLocation > 0 && naiveNewLocation < stringView.string.length else {
            return naiveNewLocation
        }
        let range = stringView.string.customRangeOfComposedCharacterSequence(at: naiveNewLocation)
        guard naiveNewLocation > range.location && naiveNewLocation < range.location + range.length else {
            return naiveNewLocation
        }
        if offset < 0 {
            return sourceLocation - range.length
        } else {
            return sourceLocation + range.length
        }
    }

    private func location(movingFrom sourceLocation: Int, byLineCount offset: Int) -> Int {
        #if os(iOS)
        return lineNavigationService.location(movingFrom: sourceLocation, byOffset: offset)
        #else
        // Attempts to simulate the behavior of UIKit and UITextInput. By using previousLineMovementOperation we can remember the local location within lines when navigating to shorter lines.
        if let previousLineMovementOperation {
            let newOffset = previousLineMovementOperation.offset + offset
            let overridenSourceLocation = previousLineMovementOperation.sourceLocation
            self.previousLineMovementOperation = LineMovementOperation(sourceLocation: overridenSourceLocation, offset: newOffset)
            return lineNavigationService.location(movingFrom: overridenSourceLocation, byOffset: newOffset)
        } else {
            previousLineMovementOperation = LineMovementOperation(sourceLocation: sourceLocation, offset: offset)
            return lineNavigationService.location(movingFrom: sourceLocation, byOffset: offset)
        }
        #endif
    }

    private func location(movingFrom sourceLocation: Int, byWordCount offset: Int) -> Int {
        // This attempts to reproduce the logic of UIKit and UITextInput calling an instance of UITextInputTokenizer.
        let direction: StringTokenizer.Direction = offset > 0 ? .forward : .backward
        var destinationLocation: Int? = sourceLocation
        var remainingOffset = abs(offset)
        // Run once for each word that we should offset.
        while let newSourceLocation = destinationLocation, remainingOffset > 0 {
            guard let tmpDestinationLocation = stringTokenizer.location(
                from: newSourceLocation,
                toBoundary: .word,
                inDirection: direction
            ) else {
                destinationLocation = nil
                continue
            }
            // If we end up at the boundary of a word then we run once more.
            if stringTokenizer.isLocation(tmpDestinationLocation, atBoundary: .word, inDirection: direction.opposite) {
                remainingOffset += 1
            }
            destinationLocation = tmpDestinationLocation
            remainingOffset -= 1
        }
        return destinationLocation ?? sourceLocation
    }
}

private extension StringTokenizer.Direction {
    var opposite: StringTokenizer.Direction {
        switch self {
        case .forward:
            return .backward
        case .backward:
            return .forward
        }
    }
}
