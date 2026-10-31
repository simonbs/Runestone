import Foundation

open class RedBlackTreeChildrenUpdater<NodeID: RedBlackTreeNodeID, NodeValue: RedBlackTreeNodeValue, NodeData> {
    public typealias Node = RedBlackTreeNode<NodeID, NodeValue, NodeData>

    public init() {}

    open func updateAfterChangingChildren(of node: Node) -> Bool {
        false
    }
}
