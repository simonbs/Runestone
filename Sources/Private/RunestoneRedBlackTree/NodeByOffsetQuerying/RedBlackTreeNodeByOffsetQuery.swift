import Foundation

package protocol RedBlackTreeNodeByOffsetQuery {
    associatedtype NodeValue: RedBlackTreeNodeValue
    associatedtype NodeData
    associatedtype Offset: Comparable & AdditiveArithmetic
    typealias Node = RedBlackTreeNode<NodeValue, NodeData>
    var targetOffset: Offset { get }
    var minimumOffset: Offset { get }
    func offset(for node: Node) -> Offset
    func totalOffset(for node: Node) -> Offset
}
