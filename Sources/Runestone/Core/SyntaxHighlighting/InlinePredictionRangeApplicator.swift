import Combine
import Foundation

final class InlinePredictionRangeApplicator {
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let lineControllerStorage: LineControllerStorage
    private var cancellables: Set<AnyCancellable> = []

    init(
        lineManager: CurrentValueSubject<LineManager, Never>,
        lineControllerStorage: LineControllerStorage,
        inlinePredictionRange: CurrentValueSubject<NSRange?, Never>
    ) {
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        inlinePredictionRange.removeDuplicates().sink { [weak self] inlinePredictionRange in
            self?.applyInlinePredictionRange(inlinePredictionRange)
        }.store(in: &cancellables)
    }
}

private extension InlinePredictionRangeApplicator {
    private func applyInlinePredictionRange(_ inlinePredictionRange: NSRange?) {
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
