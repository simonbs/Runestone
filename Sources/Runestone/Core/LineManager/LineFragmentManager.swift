import _RunestoneRedBlackTree
import CoreGraphics

final class LineFragmentManager {
    var numberOfLineFragments: Int {
        tree.nodeTotalCount
    }

    private var tree = RedBlackTree(minimumValue: 0, rootValue: 0, rootData: ManagedLineFragment())

    func reset() {
        tree = RedBlackTree(minimumValue: 0, rootValue: 0, rootData: ManagedLineFragment())
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
                node.updateTotalHeight()
                tree.updateAfterChangingChildren(of: node)
                previousNode = node
            } else if let thisPreviousNode = previousNode {
                let newNode = tree.insertNode(value: length, data: lineFragment, after: thisPreviousNode)
                newNode.updateTotalHeight()
                previousNode = newNode
            } else {
                let thisPreviousNode = tree.node(atIndex: typesetLineFragment.index - 1)
                let newNode = tree.insertNode(value: length, data: lineFragment, after: thisPreviousNode)
                newNode.updateTotalHeight()
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
}

private extension RedBlackTreeNode where NodeData == ManagedLineFragment {
    func updateTotalHeight() {
        data.totalHeight = previous.data.totalHeight + data.scaledSize.height
    }
}
