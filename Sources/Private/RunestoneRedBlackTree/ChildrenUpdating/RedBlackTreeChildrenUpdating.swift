import Foundation

package protocol RedBlackTreeChildrenUpdating {
    associatedtype NodeValue: RedBlackTreeNodeValue
    associatedtype NodeData
    typealias Node = RedBlackTreeNode<NodeValue, NodeData>
    @discardableResult
    func updateChildren(of node: Node) -> Bool
}
