import Foundation

struct TotalCountRedBlackTreeChildrenUpdater<
    _NodeValue: RedBlackTreeNodeValue, _NodeData>
: RedBlackTreeChildrenUpdating {
    typealias NodeValue = _NodeValue
    typealias NodeData = _NodeData

    func updateChildren(of node: Node) -> Bool {
        var totalCount = 1
        if let leftNode = node.left {
            totalCount += leftNode.nodeTotalCount
        }
        if let rightNode = node.right {
            totalCount += rightNode.nodeTotalCount
        }
        let hasTotalCountChanged = totalCount != node.nodeTotalCount
        if hasTotalCountChanged {
            node.nodeTotalCount = totalCount
        }
        return hasTotalCountChanged
    }
}
