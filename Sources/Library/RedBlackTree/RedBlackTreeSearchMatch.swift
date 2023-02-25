import Foundation

public final class RedBlackTreeSearchMatch<NodeID: RedBlackTreeNodeID, NodeValue: RedBlackTreeNodeValue, Data> {
    public typealias Node = RedBlackTreeNode<NodeID, NodeValue, Data>

    public let location: NodeValue
    public let value: NodeValue
    public let node: Node

    init(location: NodeValue, value: NodeValue, node: Node) {
        self.location = location
        self.value = value
        self.node = node
    }
}
