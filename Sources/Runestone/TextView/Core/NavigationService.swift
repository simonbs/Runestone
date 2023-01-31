import Foundation

final class NavigationService {
    enum Granularity {
        case character
        case line
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
    private var previousLineMovementOperation: LineMovementOperation?

    init(stringView: StringView, lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.stringView = stringView
        self.lineNavigationService = LineNavigationService(
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }

    func location(movingFrom sourceLocation: Int, by granularity: Granularity, offset: Int) -> Int {
        switch granularity {
        case .character:
            previousLineMovementOperation = nil
            return location(movingFrom: sourceLocation, byCharacterCount: offset)
        case .line:
            #if os(iOS)
            return lineNavigationService.location(movingFrom: sourceLocation, byOffset: offset)
            #else
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
}
