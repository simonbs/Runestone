import Foundation

struct TotalValueRedBlackTreeChildrenUpdater<
    _NodeValue: RedBlackTreeNodeValue, _NodeData>
: RedBlackTreeChildrenUpdating {
    typealias NodeValue = _NodeValue
    typealias NodeData = _NodeData

    func updateChildren(of node: Node) -> Bool {
        var totalValue = node.value
        if let leftNode = node.left {
            totalValue += leftNode.nodeTotalValue
        }
        if let rightNode = node.right {
            totalValue += rightNode.nodeTotalValue
        }
        let hasTotalValueChanged = totalValue != node.nodeTotalValue
        if hasTotalValueChanged {
            node.nodeTotalValue = totalValue
        }
        return hasTotalValueChanged
    }
}
