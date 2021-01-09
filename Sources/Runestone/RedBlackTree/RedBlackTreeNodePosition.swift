//
//  File.swift
//  
//
//  Created by Simon Støvring on 09/01/2021.
//

import Foundation

final class RedBlackTreeNodePosition<Context> {
    let location: Int
    let index: Int
    let value: Int
    let valueOffset: Int
    let context: Context

    init(location: Int, index: Int, value: Int, valueOffset: Int, context: Context) {
        self.location = location
        self.index = index
        self.value = value
        self.valueOffset = valueOffset
        self.context = context
    }
}

extension RedBlackTree {
    func nodePosition(at value: Int) -> RedBlackTreeNodePosition<Context>? {
        guard value >= 0 && value <= root.totalNodeValue else {
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
            var location = 0
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
                    if remainingValue < 0 {
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
