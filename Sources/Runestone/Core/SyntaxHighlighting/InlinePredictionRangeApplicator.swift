import Combine
import Foundation

final class InlinePredictionRangeApplicator<LineManagerType: LineManaging> {
    private let lineManager: LineManagerType

    init(lineManager: LineManagerType) {
        self.lineManager = lineManager
//        inlinePredictionRange.removeDuplicates().sink { [weak self] inlinePredictionRange in
//            self?.applyInlinePredictionRange(inlinePredictionRange)
//        }.store(in: &cancellables)
    }
}

private extension InlinePredictionRangeApplicator {
    private func applyInlinePredictionRange(_ inlinePredictionRange: NSRange?) {
//        let iterator = lineControllerStore.makeIterator()
//        for lineController in iterator {
//            guard let inlinePredictionRange else {
//                lineController.inlinePredictionRange = nil
//                continue
//            }
//            let line = lineController.line
//            let lineRange = NSRange(location: line.location, length: line.data.totalLength)
//            guard inlinePredictionRange.overlaps(lineRange) else {
//                lineController.inlinePredictionRange = nil
//                continue
//            }
//            lineController.inlinePredictionRange = inlinePredictionRange.local(to: lineRange)
//        }
    }
}
