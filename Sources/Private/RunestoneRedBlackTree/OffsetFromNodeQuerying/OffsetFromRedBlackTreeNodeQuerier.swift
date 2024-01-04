import Foundation

package struct OffsetFromRedBlackTreeNodeQuerier<NodeValue: RedBlackTreeNodeValue, NodeData> {
    private let tree: RedBlackTree<NodeValue, NodeData>

    package init(querying tree: RedBlackTree<NodeValue, NodeData>) {
        self.tree = tree
    }

    package func offset<Query: OffsetFromRedBlackTreeNodeQuery>(
        for query: Query
    ) -> Query.Offset? where Query.NodeValue == NodeValue, Query.NodeData == NodeData {
        // The implementation is inspired by GetOffsetFromNode() in AvalonEdit.
        // https://github.com/icsharpcode/AvalonEdit/blob/master/ICSharpCode.AvalonEdit/Document/DocumentLineTree.cs#L201C23-L201C40
        var offset = if let leftNode = query.targetNode.left {
            query.totalOffset(for: leftNode)
        } else {
            query.minimumValue
        }
        var workingNode = query.targetNode
        while let parentNode = workingNode.parent {
            if workingNode === workingNode.parent?.right {
                if let leftNode = workingNode.parent?.left {
                    offset += query.totalOffset(for: leftNode)
                }
                offset += query.offset(for: parentNode)
            }
            workingNode = parentNode
        }
        return offset
    }
}
