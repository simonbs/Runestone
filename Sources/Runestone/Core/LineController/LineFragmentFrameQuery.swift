import _RunestoneRedBlackTree
import CoreGraphics

final class LineFragmentFrameQuery<LineFragmentType: LineFragment>: RedBlackTreeTraversingSearchQuery {
    typealias NodeValue = Int
    typealias NodeData = LineFragmentNodeData
    typealias Node = RedBlackTreeNode<Int, LineFragmentNodeData>

    private let range: ClosedRange<CGFloat>

    init(range: ClosedRange<CGFloat>) {
        self.range = range
    }

    func shouldTraverseLeftChildren(of node: Node) -> Bool {
        node.data.totalLineFragmentHeight >= range.lowerBound
    }

    func shouldTraverseRightChildren(of node: Node) -> Bool {
        node.data.totalLineFragmentHeight <= range.upperBound
    }

    func isMatch(_ node: Node) -> Bool {
        let minY = node.data.totalLineFragmentHeight - node.data.lineFragmentHeight
        let maxY = node.data.totalLineFragmentHeight
        return range.overlaps(minY ... maxY)
    }
}
