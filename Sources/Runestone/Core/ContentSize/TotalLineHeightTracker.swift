import Combine
import Foundation

final class TotalLineHeightTracker<LineManagerType: LineManaging> {
    @Published private(set) var isTotalLineHeightInvalid = false
    var totalLineHeight: CGFloat {
        if let cachedTotalLinesHeight {
            return cachedTotalLinesHeight
        } else {
//            let totalLinesHeight = lineManager.contentHeight
//            cachedTotalLinesHeight = totalLinesHeight
//            return totalLinesHeight
            return 0
        }
    }
    
    private let lineManager: LineManagerType
    private var cachedTotalLinesHeight: CGFloat?
    private var lineManagerCancellable: AnyCancellable?
    private var didInsertOrRemoveLineCancellable: AnyCancellable?

    init(lineManager: LineManagerType) {
        self.lineManager = lineManager
//        lineManagerCancellable = lineManager.sink { [weak self] lineManager in
//            self?.didInsertOrRemoveLineCancellable = Publishers.CombineLatest(
//                lineManager.didInsertLine,
//                lineManager.didRemoveLine
//            ).sink { [weak self] _ in
//                self?.cachedTotalLinesHeight = nil
//                self?.isTotalLineHeightInvalid = true
//            }
//        }
    }

    func reset() {
        cachedTotalLinesHeight = nil
        isTotalLineHeightInvalid = true
    }

    func setHeight(of line: LineNode, to newHeight: CGFloat) {
        guard abs(newHeight - line.data.height) >= CGFloat.ulpOfOne else {
            return
        }
//        line.data.height = newHeight
//        lineManager.updateAfterChangingChildren(of: line)
        cachedTotalLinesHeight = nil
        isTotalLineHeightInvalid = true
    }
}
