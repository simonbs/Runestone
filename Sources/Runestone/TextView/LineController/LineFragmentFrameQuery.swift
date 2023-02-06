import CoreGraphics

final class LineFragmentFrameQuery: RedBlackTreeSearchQuery {
    typealias NodeID = LineFragmentNodeID
    typealias NodeValue = Int
    typealias NodeData = LineFragmentNodeData

    private let range: ClosedRange<CGFloat>

    init(range: ClosedRange<CGFloat>) {
        self.range = range
    }

    func shouldTraverseLeftChildren(of node: RedBlackTreeNode<LineFragmentNodeID, Int, LineFragmentNodeData>) -> Bool {
        node.data.totalLineFragmentHeight >= range.lowerBound
    }

    func shouldTraverseRightChildren(of node: RedBlackTreeNode<LineFragmentNodeID, Int, LineFragmentNodeData>) -> Bool {
        node.data.totalLineFragmentHeight <= range.upperBound
    }

    func shouldInclude(_ node: RedBlackTreeNode<LineFragmentNodeID, Int, LineFragmentNodeData>) -> Bool {
        let minY = node.data.totalLineFragmentHeight - node.data.lineFragmentHeight
        let maxY = node.data.totalLineFragmentHeight
        return range.overlaps(minY ... maxY)
    }
}
