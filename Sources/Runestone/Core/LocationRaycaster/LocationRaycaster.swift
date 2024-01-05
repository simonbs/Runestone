import _RunestoneMultiPlatform
import Combine
import CoreGraphics

struct LocationRaycaster<LineManagerType: LineManaging> {
    private let stringView: StringView
    private let lineManager: LineManagerType
    private let textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>

    init(
        stringView: StringView,
        lineManager: LineManagerType,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.textContainerInset = textContainerInset
    }

    func location(closestTo point: CGPoint) -> Int {
        return 0
//        let point = CGPoint(x: point.x - textContainerInset.value.left, y: point.y - textContainerInset.value.top)
//        if let line = lineManager.line(containingYOffset: point.y), let lineController = LineControllerStore[line.id] {
//            return closestIndex(to: point, in: lineController)
//        } else if point.y <= 0 {
//            let firstLine = lineManager.firstLine
//            if let lineController = LineControllerStore[firstLine.id] {
//                return closestIndex(to: point, in: lineController)
//            } else {
//                return 0
//            }
//        } else {
//            let lastLine = lineManager.lastLine
//            if point.y >= lastLine.yPosition, let lineController = LineControllerStore[lastLine.id] {
//                return closestIndex(to: point, in: lineController)
//            } else {
//                return stringView.length
//            }
//        }
    }
}

private extension LocationRaycaster {
    private func closestIndex(to point: CGPoint, in line: some Line) -> Int {
        let localPoint = CGPoint(x: point.x, y: point.y - line.yPosition)
        return line.location(closestTo: localPoint)
    }
}
