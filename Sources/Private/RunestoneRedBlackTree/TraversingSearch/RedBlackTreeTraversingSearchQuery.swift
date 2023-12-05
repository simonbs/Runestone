import Foundation

package protocol RedBlackTreeTraversingSearchQuery {
    associatedtype NodeValue: RedBlackTreeNodeValue
    associatedtype NodeData
    func shouldTraverseLeftChildren(of node: RedBlackTreeNode<NodeValue, NodeData>) -> Bool
    func shouldTraverseRightChildren(of node: RedBlackTreeNode<NodeValue, NodeData>) -> Bool
    func isMatch(_ node: RedBlackTreeNode<NodeValue, NodeData>) -> Bool
}
