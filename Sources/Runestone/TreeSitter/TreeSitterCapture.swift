//
//  TreeSitterCapture.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation

final class TreeSitterCapture {
    let node: TreeSitterNode
    let index: UInt32
    let name: String
    let byteRange: ByteRange
    let properties: [String: String]
    let textPredicates: [TreeSitterTextPredicate]

    convenience init(node: TreeSitterNode, index: UInt32, name: String, predicates: [TreeSitterPredicate]) {
        self.init(node: node, index: index, name: name, byteRange: node.byteRange, predicates: predicates)
    }

    private init(node: TreeSitterNode, index: UInt32, name: String, byteRange: ByteRange, predicates: [TreeSitterPredicate]) {
        let predicateMapResult = TreeSitterPredicateMapper.map(predicates)
        self.node = node
        self.index = index
        self.name = name
        self.byteRange = byteRange
        self.properties = predicateMapResult.properties
        self.textPredicates = predicateMapResult.textPredicates
    }
}

extension TreeSitterCapture: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterCapture byteRange=\(byteRange.debugDescription) name=\(name) properties=\(properties) textPredicates=\(textPredicates)]"
    }
}
