import _RunestoneRedBlackTree
import Foundation

struct YPositionFromLineNodeQuery: OffsetFromRedBlackTreeNodeQuery {
    typealias NodeValue = Int
    typealias NodeData = ManagedLine
    typealias Offset = CGFloat

    let targetNode: Node
    let minimumValue: CGFloat = 0

    func offset(for node: Node) -> CGFloat {
        node.data.height
    }

    func totalOffset(for node: Node) -> CGFloat {
        node.data.totalHeight
    }
}
