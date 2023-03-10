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

    init(lineManager: CurrentValueSubject<LineManager, Never>) {
        self.lineManager = lineManager
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
