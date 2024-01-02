import Foundation

package struct RedBlackTreeTraversingSearcher<
    NodeValue: RedBlackTreeNodeValue, NodeData
> {
    package typealias Tree = RedBlackTree<NodeValue, NodeData>
    package typealias Match = RedBlackTreeTraversingSearchMatch<NodeValue, NodeData>

    private let tree: Tree

    package init(tree: Tree) {
        self.tree = tree
    }

    package func search<Query: RedBlackTreeTraversingSearchQuery>(
        for query: Query
    ) -> [Match] where Query.NodeValue == NodeValue, Query.NodeData == NodeData {
        search(for: query, startingAt: tree.root)
    }
}

private extension RedBlackTreeTraversingSearcher {
    private func search<Query: RedBlackTreeTraversingSearchQuery>(
        for query: Query,
        startingAt node: Tree.Node
    ) -> [Match]
    where Query.NodeValue == NodeValue, Query.NodeData == NodeData {
        var matches: [Match] = []
        let nodeLowerBound = node.offset
        let nodeUpperBound = nodeLowerBound + node.value
        if query.shouldTraverseLeftChildren(of: node), let leftNode = node.left {
            let childMatches = search(for: query, startingAt: leftNode)
            matches.append(contentsOf: childMatches)
        }
        if query.isMatch(node) {
            let match = Match(offset: nodeLowerBound, value: nodeUpperBound, node: node)
            matches.append(match)
        }
        if query.shouldTraverseRightChildren(of: node), let rightNode = node.right {
            let childMatches = search(for: query, startingAt: rightNode)
            matches.append(contentsOf: childMatches)
        }
        return matches
    }
}
