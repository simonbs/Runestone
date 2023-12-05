import Foundation

struct ParentTraversingRedBlackTreeChildrenUpdater<
    _NodeValue: RedBlackTreeNodeValue, _NodeData
> : RedBlackTreeChildrenUpdating {
    typealias NodeValue = _NodeValue
    typealias NodeData = _NodeData

    private let childrenUpdater: AnyRedBlackTreeChildrenUpdater<NodeValue, NodeData>

    init<T: RedBlackTreeChildrenUpdating>(
        _ childrenUpdater: T
    ) where T.NodeValue == NodeValue, T.NodeData == NodeData {
        self.childrenUpdater = AnyRedBlackTreeChildrenUpdater(childrenUpdater)
    }

    func updateChildren(of node: Node) -> Bool {
        let didUpdate = childrenUpdater.updateChildren(of: node)
        if let parent = node.parent, didUpdate {
            _ = updateChildren(of: parent)
        }
        return didUpdate
    }
}
