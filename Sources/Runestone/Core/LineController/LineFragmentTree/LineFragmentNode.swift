import _RunestoneRedBlackTree

typealias LineFragmentNode = RedBlackTreeNode<Int, LineFragmentNodeData>

extension LineFragmentNode {
    var location: NodeValue {
        offset
    }

    func updateTotalLineFragmentHeight() {
        data.totalLineFragmentHeight = previous.data.totalLineFragmentHeight + data.lineFragmentHeight
    }
}
