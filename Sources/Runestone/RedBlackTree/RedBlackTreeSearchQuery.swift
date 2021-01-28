//
//  RedBlackTreeSearchQuery.swift
//  
//
//  Created by Simon Støvring on 10/01/2021.
//

import Foundation

protocol RedBlackTreeSearchQuery {
    associatedtype NodeID: RedBlackTreeNodeID
    associatedtype NodeValue: RedBlackTreeNodeValue
    associatedtype NodeData
    func shouldTraverseLeftChildren(of node: RedBlackTreeNode<NodeID, NodeValue, NodeData>) -> Bool
    func shouldTraverseRightChildren(of node: RedBlackTreeNode<NodeID, NodeValue, NodeData>) -> Bool
    func shouldInclude(_ node: RedBlackTreeNode<NodeID, NodeValue, NodeData>) -> Bool
}
