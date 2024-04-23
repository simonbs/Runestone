import _RunestoneRedBlackTree
import CoreGraphics

final class LineFragmentManager {
    private typealias LineFragmentNode = RedBlackTreeNode<Int, ManagedLineFragment>

    var numberOfLineFragments: Int {
        tree.nodeTotalCount
    }

    private var tree: RedBlackTree = .forLineFragments

    func reset() {
        tree = .forLineFragments
    }

    func addTypesetLineFragments(_ typesetLineFragments: [TypesetLineFragment]) {
        var previousNode: RedBlackTreeNode<Int, ManagedLineFragment>?
        for typesetLineFragment in typesetLineFragments {
            let length = typesetLineFragment.range.length
            let lineFragment = ManagedLineFragment(typesetLineFragment)
            if typesetLineFragment.index < tree.nodeTotalCount {
                let node = tree.node(atIndex: typesetLineFragment.index)
                node.value = length
                node.data = lineFragment
                tree.updateAfterChangingChildren(of: node)
                previousNode = node
            } else if let thisPreviousNode = previousNode {
                let newNode = tree.insertNode(value: length, data: lineFragment, after: thisPreviousNode)
                previousNode = newNode
            } else {
                let thisPreviousNode = tree.node(atIndex: typesetLineFragment.index - 1)
                let newNode = tree.insertNode(value: length, data: lineFragment, after: thisPreviousNode)
                previousNode = newNode
            }
        }
    }

    func lineFragment(containingLocation location: Int) -> ManagedLineFragment {
        guard location >= 0 && location <= Int(tree.nodeTotalValue) else {
            fatalError(
                "Character at location \(location) is out of bounds,"
                + " expected \(location) >= 0 <= \(tree.nodeTotalValue)"
            )
        }
        let query = ValueRedBlackTreeNodeByOffsetQuery(querying: tree, for: location)
        let querier = RedBlackTreeNodeByOffsetQuerier(querying: tree)
        guard let node = querier.node(for: query) else {
            fatalError("Line fragment not found for character at location \(location)")
        }
        return node.data
    }

    func lineFragment(atIndex index: Int) -> ManagedLineFragment {
        tree.node(atIndex: index).data
    }

    func lineFragments(withYOffsetIn range: ClosedRange<CGFloat>) -> [ManagedLineFragment] {
        let query = LineFragmentFrameQuery<ManagedLineFragment>(range: range)
        let searcher = RedBlackTreeTraversingSearcher<Int, ManagedLineFragment>(tree: tree)
        return searcher.search(for: query).map(\.node.data)
    }

    func lineFragment(atYOffset yOffset: CGFloat) -> ManagedLineFragment? {
        let query = YOffsetRedBlackTreeNodeByOffsetQuery(querying: tree, for: yOffset)
        let querier = RedBlackTreeNodeByOffsetQuerier(querying: tree)
        let node = querier.node(for: query)
        return node?.data
    }
}

private extension LineFragmentManager {
    private func lineFragmentNode(containingCharacterAt location: Int) -> LineFragmentNode? {
        guard location >= 0 && location <= Int(tree.nodeTotalValue) else {
            return nil
        }
        let query = ValueRedBlackTreeNodeByOffsetQuery(querying: tree, for: location)
        let querier = RedBlackTreeNodeByOffsetQuerier(querying: tree)
        return querier.node(for: query)
    }
}

private extension RedBlackTree where NodeValue == Int, NodeData == ManagedLineFragment {
    static var forLineFragments: RedBlackTree<Int, ManagedLineFragment> {
        RedBlackTree(
            minimumValue: 0,
            rootValue: 0,
            rootData: ManagedLineFragment(),
            childrenUpdater: NodeTotalHeightRedBlackTreeChildrenUpdater()
        )
    }
}
