//
//  File.swift
//  
//
//  Created by Simon Støvring on 09/01/2021.
//

import Foundation

final class RedBlackTreeNodePosition<Value, Context> {
    let location: Value
    let index: Int
    let value: Value
    let valueOffset: Value
    let context: Context

    init(location: Value, index: Int, value: Value, valueOffset: Value, context: Context) {
        self.location = location
        self.index = index
        self.value = value
        self.valueOffset = valueOffset
        self.context = context
    }
}

extension RedBlackTree {
    func nodePosition(at value: Value) -> RedBlackTreeNodePosition<Value, Context>? {
        guard value >= root.value && value <= root.totalNodeValue else {
            return nil
        }
        if value == root.totalNodeValue {
            let node = root.rightMost
            let location = root.totalNodeValue - node.totalNodeValue
            let valueOffset = value - location
            return RedBlackTreeNodePosition(
                location: location,
                index: node.index,
                value: node.value,
                valueOffset: valueOffset,
                context: node.context)
        } else {
            var location = minimumValue
            var remainingValue = value
            var node = root!
            while true {
                if let leftNode = node.left, remainingValue < leftNode.totalNodeValue {
                    node = leftNode
                } else {
                    if let leftNode = node.left {
                        location += leftNode.totalNodeValue
                        remainingValue -= leftNode.totalNodeValue
                    }
                    location += node.value
                    remainingValue -= node.value
                    if remainingValue < minimumValue {
                        location -= node.value
                        let valueOffset = value - location
                        return RedBlackTreeNodePosition(
                            location: location,
                            index: node.index,
                            value: node.value,
                            valueOffset: valueOffset,
                            context: node.context)
                    } else {
                        node = node.right!
                    }
                }
            }
        }
    }
}
