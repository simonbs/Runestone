typealias LineFragmentNode = RedBlackTreeNode<LineFragmentNodeID, Int, LineFragmentNodeData>

extension LineFragmentNode {
    func updateTotalLineFragmentHeight() {
        data.totalLineFragmentHeight = previous.data.totalLineFragmentHeight + data.lineFragmentHeight
    }
}
