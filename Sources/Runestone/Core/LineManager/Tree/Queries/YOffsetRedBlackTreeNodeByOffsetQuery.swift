import _RunestoneRedBlackTree
import Foundation

protocol YOffsetRedBlackTreeNodeByOffsetQuerable {
    var height: CGFloat { get }
    var nodeTotalHeight: CGFloat { get }
}

struct YOffsetRedBlackTreeNodeByOffsetQuery<
    T: YOffsetRedBlackTreeNodeByOffsetQuerable
>: RedBlackTreeNodeByOffsetQuery {
    typealias NodeValue = Int
    typealias NodeData = T
    typealias Offset = CGFloat

    let targetOffset: CGFloat
    let minimumOffset: CGFloat

    init(querying tree: RedBlackTree<NodeValue, NodeData>, for targetOffset: CGFloat) {
        self.targetOffset = targetOffset
        self.minimumOffset = 0
    }

    func offset(for node: Node) -> CGFloat {
        node.data.height
    }

    func totalOffset(for node: Node) -> CGFloat {
        node.data.nodeTotalHeight
    }
}
