import Foundation

package protocol OffsetFromRedBlackTreeNodeQuery {
    associatedtype NodeValue: RedBlackTreeNodeValue
    associatedtype NodeData
    associatedtype Offset: Comparable & AdditiveArithmetic
    typealias Node = RedBlackTreeNode<NodeValue, NodeData>
    var targetNode: Node { get }
    var minimumValue: Offset { get }
    func offset(for node: Node) -> Offset
    func totalOffset(for node: Node) -> Offset
}
