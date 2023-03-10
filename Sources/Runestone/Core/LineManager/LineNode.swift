import CoreGraphics

typealias LineNode = RedBlackTreeNode<LineNodeID, Int, LineNodeData>

extension LineNode {
    var yPosition: CGFloat {
        tree.yPosition(of: self)
    }

    var range: ClosedRange<Int> {
        let _location = location
        return _location ... _location + data.totalLength
    }
}
