import _RunestoneRedBlackTree
import CoreGraphics

typealias LineNode = RedBlackTreeNode<Int, ManagedLine>

extension LineNode {
    var yPosition: CGFloat {
        let query = YPositionFromLineNodeQuery(targetNode: self)
        let querier = OffsetFromRedBlackTreeNodeQuerier(querying: tree)
        return querier.offset(for: query)!
    }

    var range: ClosedRange<Int> {
        let location = offset
        return location ... location + data.totalLength
    }
}
