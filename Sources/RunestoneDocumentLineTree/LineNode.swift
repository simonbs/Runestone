//
//  File.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

protocol LineNode: class {
    var nodeTotalLength: Int { get set }
    var nodeTotalCount: Int { get }
    var parent: Self? { get }
    var left: Self? { get }
    var right: Self? { get }
}

extension LineNode {
    var leftMost: Self {
        var result = self
        while let newResult = result.left {
            result = newResult
        }
        return result
    }
    var rightMost: Self {
        var result = self
        while let newResult = result.right {
            result = newResult
        }
        return result
    }
    var previous: Self {
        if let left = left {
            return left.rightMost
        } else {
            var node: Self? = self
            var oldNode: Self? = self
            repeat {
                oldNode = node
                node = node?.parent
                // We are on the way up from the left part, don't output node again.
            } while node != nil && node?.left === oldNode
            return node!
        }
    }
    var next: Self {
        if let right = right {
            return right.leftMost
        } else {
            var node: Self? = self
            var oldNode: Self? = self
            repeat {
                oldNode = node
                node = node?.parent
                // We are on the way up from the right part, don't output node again.
            } while node != nil && node?.right === oldNode
            return node!
        }
    }
}
