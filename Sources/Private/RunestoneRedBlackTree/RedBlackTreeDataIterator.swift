import Foundation

package final class RedBlackTreeDataIterator<
    NodeValue: RedBlackTreeNodeValue, NodeData
>: IteratorProtocol, LazySequenceProtocol {
    private let iterator: RedBlackTreeIterator<NodeValue, NodeData>

    package init(tree: RedBlackTree<NodeValue, NodeData>) {
        self.iterator = RedBlackTreeIterator(tree: tree)
    }

    package func next() -> NodeData? {
        iterator.next()?.data
    }
}
