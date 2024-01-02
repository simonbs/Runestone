import Foundation

package final class RedBlackTreeTraversingSearchMatch<
    NodeValue: RedBlackTreeNodeValue, Data
> {
    package typealias Node = RedBlackTreeNode<NodeValue, Data>

    package let offset: NodeValue
    package let value: NodeValue
    package let node: Node

    init(offset: NodeValue, value: NodeValue, node: Node) {
        self.offset = offset
        self.value = value
        self.node = node
    }
}
