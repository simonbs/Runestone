import Combine
import Foundation

final class TotalLineHeightTracker {
    @Published private(set) var isTotalLineHeightInvalid = false
    var totalLineHeight: CGFloat {
        if let cachedTotalLinesHeight {
            return cachedTotalLinesHeight
        } else {
            let totalLinesHeight = lineManager.value.contentHeight
            cachedTotalLinesHeight = totalLinesHeight
            return totalLinesHeight
        }
    }
    
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private var cachedTotalLinesHeight: CGFloat?
    private var lineManagerCancellable: AnyCancellable?
    private var didInsertOrRemoveLineCancellable: AnyCancellable?

    init(lineManager: CurrentValueSubject<LineManager, Never>) {
        self.lineManager = lineManager
        lineManagerCancellable = lineManager.sink { [weak self] lineManager in
            self?.didInsertOrRemoveLineCancellable = Publishers.CombineLatest(
                lineManager.didInsertLine,
                lineManager.didRemoveLine
            ).sink { [weak self] _ in
                self?.cachedTotalLinesHeight = nil
                self?.isTotalLineHeightInvalid = true
            }
        }
    }

    func reset() {
        cachedTotalLinesHeight = nil
        isTotalLineHeightInvalid = true
    }

    func setHeight(of line: LineNode, to newHeight: CGFloat) {
        guard abs(newHeight - line.data.lineHeight) >= CGFloat.ulpOfOne else {
            return
        }
        line.data.lineHeight = newHeight
        lineManager.value.updateAfterChangingChildren(of: line)
        cachedTotalLinesHeight = nil
        isTotalLineHeightInvalid = true
    }
}
