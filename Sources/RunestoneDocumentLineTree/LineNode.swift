//
//  File.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

protocol LineNode: class {
    var nodeTotalLength: Int { get }
    var nodeTotalCount: Int { get }
    var parent: Self? { get }
    var left: Self? { get }
    var right: Self? { get }
}

extension LineNode {
    var leftMost: Self {
        var node = self
        while let newNode = node.left {
            node = newNode
        }
        return node
    }
    var rightMost: Self {
        var node = self
        while let newNode = node.right {
            node = newNode
        }
        return node
    }
    var previous: Self {
        if let left = left {
            return left.rightMost
        } else {
            var oldNode = self
            var node = parent ?? self
            while let parent = node.parent, node.left === oldNode {
                oldNode = node
                node = parent
            }
            return node
        }
    }
    var next: Self {
        if let right = right {
            return right.leftMost
        } else {
            var oldNode = self
            var node = parent ?? self
            while let parent = node.parent, node.right === oldNode {
                oldNode = node
                node = parent
            }
            return node
        }
    }
}
