import CoreGraphics
import Foundation

final class LineFragmentCharacterLocationQuery: RedBlackTreeSearchQuery {
    typealias NodeID = LineFragmentNodeID
    typealias NodeValue = Int
    typealias NodeData = LineFragmentNodeData

    private let range: NSRange

    init(range: NSRange) {
        self.range = range
    }

    func shouldTraverseLeftChildren(of node: RedBlackTreeNode<LineFragmentNodeID, Int, LineFragmentNodeData>) -> Bool {
        node.nodeTotalValue >= range.lowerBound
    }

    func shouldTraverseRightChildren(of node: RedBlackTreeNode<LineFragmentNodeID, Int, LineFragmentNodeData>) -> Bool {
        node.nodeTotalValue <= range.upperBound
    }

    func shouldInclude(_ node: RedBlackTreeNode<LineFragmentNodeID, Int, LineFragmentNodeData>) -> Bool {
        let startLocation = node.location
        let endLocation = startLocation + node.value
        let nodeRange = startLocation ... endLocation
        let needleRange = range.lowerBound ... range.upperBound
        return nodeRange.overlaps(needleRange)
    }
}
