import _RunestoneRedBlackTree
import CoreGraphics

struct LineFragmentFrameQuery<LineFragmentType: LineFragment>: RedBlackTreeTraversingSearchQuery {
    typealias NodeValue = Int
    typealias NodeData = LineFragmentType
    typealias Node = RedBlackTreeNode<Int, LineFragmentType>

    let range: ClosedRange<CGFloat>

    func shouldTraverseLeftChildren(of node: Node) -> Bool {
        node.data.totalHeight >= range.lowerBound
    }

    func shouldTraverseRightChildren(of node: Node) -> Bool {
        node.data.totalHeight <= range.upperBound
    }

    func isMatch(_ node: Node) -> Bool {
        range.overlaps(node.data.totalHeight - node.data.scaledSize.height ... node.data.totalHeight)
    }
}
