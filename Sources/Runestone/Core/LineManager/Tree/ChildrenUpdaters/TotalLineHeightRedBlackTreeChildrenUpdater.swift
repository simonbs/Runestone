import _RunestoneRedBlackTree
import Foundation

struct TotalLineHeightRedBlackTreeChildrenUpdater: RedBlackTreeChildrenUpdating {
    typealias NodeValue = Int
    typealias NodeData = ManagedLine

    func updateChildren(of node: Node) -> Bool {
        var totalHeight = node.data.height
        if let leftNode = node.left {
            totalHeight += leftNode.data.totalHeight
        }
        if let rightNode = node.right {
            totalHeight += rightNode.data.totalHeight
        }
        if totalHeight != node.data.totalHeight {
            node.data.totalHeight = totalHeight
            return true
        } else {
            return false
        }
    }
}
