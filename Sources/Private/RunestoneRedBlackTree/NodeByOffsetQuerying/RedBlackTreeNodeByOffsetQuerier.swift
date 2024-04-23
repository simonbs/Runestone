import Foundation

package struct RedBlackTreeNodeByOffsetQuerier<NodeValue: RedBlackTreeNodeValue, NodeData> {
    package typealias Tree = RedBlackTree<NodeValue, NodeData>

    private let tree: Tree

    package init(querying tree: Tree) {
        self.tree = tree
    }

    package func node<Query: RedBlackTreeNodeByOffsetQuery>(
        for query: Query
    ) -> Tree.Node? where Query.NodeValue == NodeValue, Query.NodeData == NodeData {
        // The implementation is inspired by GetNodeByOffset() in AvalonEdit.
        // https://github.com/icsharpcode/AvalonEdit/blob/master/ICSharpCode.AvalonEdit/Document/DocumentLineTree.cs#L178
        guard query.targetOffset != query.totalOffset(for: tree.root) else {
            return tree.root.rightMost
        }
        var remainingOffset = query.targetOffset
        var node = tree.root!
        while true {
            if let leftNode = node.left, remainingOffset < query.totalOffset(for: leftNode) {
                node = leftNode
            } else {
                if let leftNode = node.left {
                    remainingOffset -= query.totalOffset(for: leftNode)
                }
                remainingOffset -= query.offset(for: node)
                if remainingOffset < query.minimumOffset {
                    return node
                } else if let rightNode = node.right {
                    node = rightNode
                } else {
                    return nil
                }
            }
        }
    }
}
