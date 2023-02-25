import Foundation
import LineManager

final class StatefulLineNavigationLocationFactory {
    private struct MoveOperation {
        let location: Int
        let offset: DirectionedOffset
        let destinationLocation: Int
    }

    fileprivate struct DirectionedOffset {
        let rawValue: Int
        var offset: Int {
            abs(rawValue)
        }
        var direction: TextDirection {
            rawValue < 0 ? .backward : .forward
        }

        init(offset: Int, inDirection direction: TextDirection) {
            switch direction {
            case .forward:
                rawValue = offset < 0 ? offset * -1 : offset
            case .backward:
                rawValue = offset > 0 ? offset * -1 : offset
            }
        }

        fileprivate init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    private let lineManager: LineManager
    private let lineControllerStorage: LineControllerStorage
    private var previousOperation: MoveOperation?
    private var lineNavigationLocationFactory: LineNavigationLocationFactory {
        LineNavigationLocationFactory(lineManager: lineManager, lineControllerStorage: lineControllerStorage)
    }

    init(lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
    }

    func location(movingFrom location: Int, byLineCount offset: Int = 1, inDirection direction: TextDirection) -> Int {
        if let previousOperation {
            let directionedOffset = DirectionedOffset(offset: offset, inDirection: direction)
            let newDirectionedOffset = previousOperation.offset + directionedOffset
            let newOperation = operation(
                movingFrom: previousOperation.location,
                byLineCount: newDirectionedOffset.offset,
                inDirection: newDirectionedOffset.direction
            )
            if newOperation.destinationLocation != previousOperation.destinationLocation {
                self.previousOperation = newOperation
            }
            return newOperation.destinationLocation
        } else {
            let operation = operation(movingFrom: location, byLineCount: offset, inDirection: direction)
            previousOperation = operation
            return operation.destinationLocation
        }
    }

    func reset() {
        previousOperation = nil
    }
}

private extension StatefulLineNavigationLocationFactory {
    private func operation(movingFrom location: Int, byLineCount offset: Int, inDirection direction: TextDirection) -> MoveOperation {
        let directionedOffset = DirectionedOffset(offset: offset, inDirection: direction)
        let destinationLocation = lineNavigationLocationFactory.location(movingFrom: location, byLineCount: offset, inDirection: direction)
        return MoveOperation(location: location, offset: directionedOffset, destinationLocation: destinationLocation)
    }
}

extension StatefulLineNavigationLocationFactory.DirectionedOffset {
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(rawValue: lhs.rawValue + rhs.rawValue)
    }
}
