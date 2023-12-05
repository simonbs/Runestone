import Foundation

package struct ValueRedBlackTreeNodeByOffsetQuery<
    NodeValueType: RedBlackTreeNodeValue,
    NodeDataType
>: RedBlackTreeNodeByOffsetQuery {
    package typealias NodeValue = NodeValueType
    package typealias NodeData = NodeDataType
    package typealias Offset = NodeValueType

    package let targetOffset: NodeValueType

    package init(querying tree: RedBlackTree<NodeValue, NodeData>, for targetOffset: NodeValueType) {
        self.targetOffset = targetOffset
    }

    package func offset(for node: Node) -> NodeValueType {
        node.value
    }

    package func totalOffset(for node: Node) -> NodeValueType {
        node.nodeTotalValue
    }
}
