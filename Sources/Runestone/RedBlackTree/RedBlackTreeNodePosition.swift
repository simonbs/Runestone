//
//  RedBlackTreeNodePosition.swift
//  
//
//  Created by Simon Støvring on 09/12/2020.
//

import Foundation

public final class RedBlackTreeNodePosition<NodeValue> {
    public let nodeStartLocation: NodeValue
    public let index: Int
    public let offset: NodeValue
    public let value: NodeValue

    init(nodeStartLocation: NodeValue, index: Int, offset: NodeValue, value: NodeValue) {
        self.nodeStartLocation = nodeStartLocation
        self.index = index
        self.offset = offset
        self.value = value
    }
}
