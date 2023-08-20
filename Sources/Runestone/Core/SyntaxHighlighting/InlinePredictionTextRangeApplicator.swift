import Combine
import Foundation

final class InlinePredictionTextRangeApplicator {
    var inlinePredictionRange: NSRange? {
        didSet {
            if inlinePredictionRange != oldValue {
                for lineController in lineControllerStorage {
                    guard let inlinePredictionRange else {
                        lineController.inlinePredictionRange = nil
                        continue
                    }
                    let line = lineController.line
                    let lineRange = NSRange(location: line.location, length: line.data.totalLength)
                    guard inlinePredictionRange.overlaps(lineRange) else {
                        lineController.inlinePredictionRange = nil
                        continue
                    }
                    lineController.inlinePredictionRange = inlinePredictionRange.local(to: lineRange)
                }
            }
        }
    }

    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let lineControllerStorage: LineControllerStorage

    init(lineManager: CurrentValueSubject<LineManager, Never>, lineControllerStorage: LineControllerStorage) {
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
    }
}
