import Foundation

package final class RedBlackTreeIterator<
    NodeValue: RedBlackTreeNodeValue, NodeData
>: IteratorProtocol, LazySequenceProtocol {
    private let tree: RedBlackTree<NodeValue, NodeData>
    private var node: RedBlackTreeNode<NodeValue, NodeData>?

    package init(tree: RedBlackTree<NodeValue, NodeData>) {
        self.tree = tree
        self.node = tree.root.leftMost
    }

    package func next() -> RedBlackTreeNode<NodeValue, NodeData>? {
        let currentNode = node
        if let rightNode = node?.right {
            node = rightNode.leftMost
        } else {
            while node?.parent != nil, node == node?.parent?.right {
                node = node?.parent
            }
            node = node?.parent
        }
        return currentNode
    }
}
