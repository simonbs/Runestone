import Foundation

package struct CompositeRedBlackTreeChildrenUpdater<
    _NodeValue: RedBlackTreeNodeValue, _NodeData>
: RedBlackTreeChildrenUpdating {
    package typealias NodeValue = _NodeValue
    package typealias NodeData = _NodeData

    private let childrenUpdaters: [AnyRedBlackTreeChildrenUpdater<NodeValue, NodeData>]

    package init<T: RedBlackTreeChildrenUpdating>(
        _ childrenUpdaters: [T]
    ) where T.NodeValue == NodeValue, T.NodeData == NodeData {
        self.childrenUpdaters = childrenUpdaters.map(AnyRedBlackTreeChildrenUpdater.init)
    }

    package func updateChildren(of node: Node) -> Bool {
        var result = false
        for childrenUpdater in childrenUpdaters {
            let didUpdate = childrenUpdater.updateChildren(of: node)
            if didUpdate {
                result = didUpdate
            }
        }
        return result
    }
}
