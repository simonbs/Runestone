import Foundation

struct IndexFromRedBlackTreeNodeQuery<
    NodeValueType: RedBlackTreeNodeValue,
    NodeDataType
>: OffsetFromRedBlackTreeNodeQuery {
    typealias NodeValue = NodeValueType
    typealias NodeData = NodeDataType
    typealias Offset = Int

    let targetNode: Node
    let minimumValue: Int

    func offset(for node: Node) -> Offset {
        1
    }

    func totalOffset(for node: Node) -> Offset {
        node.nodeTotalCount
    }
}
