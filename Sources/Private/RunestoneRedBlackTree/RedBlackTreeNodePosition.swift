package final class RedBlackTreeNodePosition<NodeValue> {
    package let nodeStartLocation: NodeValue
    package let index: Int
    package let offset: NodeValue
    package let value: NodeValue

    package init(
        nodeStartLocation: NodeValue, 
        index: Int, 
        offset: NodeValue,
        value: NodeValue
    ) {
        self.nodeStartLocation = nodeStartLocation
        self.index = index
        self.offset = offset
        self.value = value
    }
}
