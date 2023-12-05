import Foundation

struct NullObjectRedBlackTreeChildrenUpdater<
    _NodeValue: RedBlackTreeNodeValue, _NodeData>
: RedBlackTreeChildrenUpdating {
    typealias NodeValue = _NodeValue
    typealias NodeData = _NodeData

    func updateChildren(of node: Node) -> Bool {
        false
    }
}
