import Combine
import CoreGraphics

struct LocationRaycaster {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let lineControllerStorage: LineControllerStorage
    private let textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        lineControllerStorage: LineControllerStorage,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.textContainerInset = textContainerInset
    }

    func location(closestTo point: CGPoint) -> Int {
        let point = CGPoint(x: point.x - textContainerInset.value.left, y: point.y - textContainerInset.value.top)
        if let line = lineManager.value.line(containingYOffset: point.y), let lineController = lineControllerStorage[line.id] {
            return closestIndex(to: point, in: lineController)
        } else if point.y <= 0 {
            let firstLine = lineManager.value.firstLine
            if let lineController = lineControllerStorage[firstLine.id] {
                return closestIndex(to: point, in: lineController)
            } else {
                return 0
            }
        } else {
            let lastLine = lineManager.value.lastLine
            if point.y >= lastLine.yPosition, let lineController = lineControllerStorage[lastLine.id] {
                return closestIndex(to: point, in: lineController)
            } else {
                return stringView.value.string.length
            }
        }
    }
}

private extension LocationRaycaster {
    private func closestIndex(to point: CGPoint, in lineController: LineController) -> Int {
        let line = lineController.line
        let localPoint = CGPoint(x: point.x, y: point.y - line.yPosition)
        return lineController.location(closestTo: localPoint)
    }
}
