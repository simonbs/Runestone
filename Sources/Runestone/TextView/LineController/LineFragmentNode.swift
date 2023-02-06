import CoreGraphics
import Foundation

struct LineFragmentNodeID: RedBlackTreeNodeID {
    let id = UUID()
}

final class LineFragmentNodeData {
    var lineFragment: LineFragment?
    var lineFragmentHeight: CGFloat {
        lineFragment?.scaledSize.height ?? 0
    }
    var totalLineFragmentHeight: CGFloat = 0

    init(lineFragment: LineFragment?) {
        self.lineFragment = lineFragment
    }
}

typealias LineFragmentNode = RedBlackTreeNode<LineFragmentNodeID, Int, LineFragmentNodeData>

extension LineFragmentNode {
    func updateTotalLineFragmentHeight() {
        data.totalLineFragmentHeight = previous.data.totalLineFragmentHeight + data.lineFragmentHeight
    }
}
