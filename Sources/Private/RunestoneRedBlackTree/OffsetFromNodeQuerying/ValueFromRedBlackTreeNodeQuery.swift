import Foundation

struct ValueOffsetFromRedBlackTreeNodeQuery<
    NodeValueType: RedBlackTreeNodeValue,
    NodeDataType
>: OffsetFromRedBlackTreeNodeQuery {
    typealias NodeValue = NodeValueType
    typealias NodeData = NodeDataType
    typealias Offset = NodeValueType

    let targetNode: Node
    let minimumValue: NodeValueType

    func offset(for node: Node) -> NodeValueType {
        node.value
    }

    func totalOffset(for node: Node) -> NodeValueType {
        node.nodeTotalValue
    }
}

