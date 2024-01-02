import Foundation

package struct AnyRedBlackTreeChildrenUpdater<
    _NodeValue: RedBlackTreeNodeValue, _NodeData>
: RedBlackTreeChildrenUpdating {
    package typealias NodeValue = _NodeValue
    package typealias NodeData = _NodeData

    private let _updateChildren: (Node) -> Bool

    package init<T: RedBlackTreeChildrenUpdating>(
        _ childrenUpdater: T
    ) where T.NodeValue == NodeValue, T.NodeData == NodeData {
        _updateChildren = { node in
            var result = false
            let didUpdate = childrenUpdater.updateChildren(of: node)
            if didUpdate {
                result = didUpdate
            }
            return result
        }
    }

    @discardableResult
    package func updateChildren(of node: Node) -> Bool {
        _updateChildren(node)
    }
}
