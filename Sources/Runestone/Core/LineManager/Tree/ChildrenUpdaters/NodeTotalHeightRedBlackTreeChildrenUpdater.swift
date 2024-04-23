import _RunestoneRedBlackTree
import Foundation

protocol NodeTotalHeightRedBlackTreeChildrenUpdatable {
    var height: CGFloat { get }
    var nodeTotalHeight: CGFloat { get set }
}

struct NodeTotalHeightRedBlackTreeChildrenUpdater<
    T: NodeTotalHeightRedBlackTreeChildrenUpdatable
>: RedBlackTreeChildrenUpdating {
    typealias NodeValue = Int
    typealias NodeData = T

    func updateChildren(of node: Node) -> Bool {
        var totalHeight = node.data.height
        if let leftNode = node.left {
            totalHeight += leftNode.data.nodeTotalHeight
        }
        if let rightNode = node.right {
            totalHeight += rightNode.data.nodeTotalHeight
        }
        let hasTotalHeightChanged = totalHeight != node.data.nodeTotalHeight
        if hasTotalHeightChanged {
            node.data.nodeTotalHeight = totalHeight
        }
        return hasTotalHeightChanged
    }
}
