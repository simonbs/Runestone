import _RunestoneRedBlackTree
import Foundation

struct YOffsetRedBlackTreeNodeByOffsetQuery: RedBlackTreeNodeByOffsetQuery {
    typealias NodeValue = Int
    typealias NodeData = ManagedLine
    typealias Offset = CGFloat

    let targetOffset: CGFloat

    init(querying tree: RedBlackTree<NodeValue, NodeData>, for targetOffset: CGFloat) {
        self.targetOffset = targetOffset
    }

    func offset(for node: Node) -> CGFloat {
        node.data.height
    }

    func totalOffset(for node: Node) -> CGFloat {
        node.data.totalHeight
    }
}
