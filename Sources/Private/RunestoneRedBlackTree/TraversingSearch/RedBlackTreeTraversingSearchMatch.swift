import Foundation

final class RedBlackTreeTraversingSearchMatch<
    NodeValue: RedBlackTreeNodeValue, Data
> {
    typealias Node = RedBlackTreeNode<NodeValue, Data>

    let offset: NodeValue
    let value: NodeValue
    let node: Node

    init(offset: NodeValue, value: NodeValue, node: Node) {
        self.offset = offset
        self.value = value
        self.node = node
    }
}
