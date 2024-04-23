import _RunestoneRedBlackTree
import CoreGraphics

struct LineFragmentFrameQuery<LineFragmentType: LineFragment>: RedBlackTreeTraversingSearchQuery {
    typealias NodeValue = Int
    typealias NodeData = LineFragmentType
    typealias Node = RedBlackTreeNode<Int, LineFragmentType>

    let range: ClosedRange<CGFloat>

    func shouldTraverseLeftChildren(of node: Node) -> Bool {
        node.data.maxYPosition >= range.lowerBound
    }

    func shouldTraverseRightChildren(of node: Node) -> Bool {
        node.data.maxYPosition <= range.upperBound
    }

    func isMatch(_ node: Node) -> Bool {
        range.overlaps(node.data.yPosition ... node.data.maxYPosition)
    }
}

private extension LineFragment {
    var maxYPosition: CGFloat {
        yPosition + scaledSize.height
    }
}
