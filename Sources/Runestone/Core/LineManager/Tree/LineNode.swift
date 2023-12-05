import _RunestoneRedBlackTree
import CoreGraphics

typealias LineNode = RedBlackTreeNode<Int, ManagedLine>

extension LineNode {
    var yPosition: CGFloat {
        let query = YPositionFromLineNodeQuery(targetNode: self)
        let querier = OffsetFromRedBlackTreeNodeQuerier(querying: tree)
        return querier.offset(for: query)!
    }

    var location: NodeValue {
        offset
    }

    var range: ClosedRange<Int> {
        let _location = location
        return _location ... _location + data.totalLength
    }
}
