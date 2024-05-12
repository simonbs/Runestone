import _RunestoneRedBlackTree
import Foundation

struct YPositionFromLineNodeQuery<StringViewType: StringView>: OffsetFromRedBlackTreeNodeQuery {
    typealias NodeValue = Int
    typealias NodeData = ManagedLine<StringViewType>
    typealias Offset = CGFloat

    let targetNode: Node
    let minimumValue: CGFloat = 0

    func offset(for node: Node) -> CGFloat {
        node.data.height
    }

    func totalOffset(for node: Node) -> CGFloat {
        node.data.nodeTotalHeight
    }
}
