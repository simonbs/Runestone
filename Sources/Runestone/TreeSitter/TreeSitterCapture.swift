//
//  TreeSitterCapture.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation

final class TreeSitterCapture {
    let node: TreeSitterNode
    let name: String
    let predicates: [TreeSitterPredicate]
    let properties: [String: String]
    let byteRange: ByteRange

    convenience init(node: TreeSitterNode, name: String, predicates: [TreeSitterPredicate]) {
        let properties = Self.extractProperties(from: predicates)
        self.init(node: node, name: name, predicates: predicates, properties: properties, byteRange: node.byteRange)
    }

    private init(node: TreeSitterNode, name: String, predicates: [TreeSitterPredicate], properties: [String: String], byteRange: ByteRange) {
        self.node = node
        self.name = name
        self.predicates = predicates
        self.properties = properties
        self.byteRange = byteRange
    }
}

private extension TreeSitterCapture {
    private static func extractProperties(from predicates: [TreeSitterPredicate]) -> [String: String] {
        var properties: [String: String] = [:]
        for predicate in predicates {
            if predicate.name == "set!", let setProperties = propertiesFromSetPredicate(predicate) {
                properties[setProperties.name] = setProperties.value
            }
        }
        return properties
    }

    private static func propertiesFromSetPredicate(_ predicate: TreeSitterPredicate) -> (name: String, value: String)? {
        guard predicate.steps.count == 2 else {
            return nil
        }
        switch (predicate.steps[0], predicate.steps[1]) {
        case (.string(let name), .string(let value)):
            return (name, value)
        default:
            return nil
        }
    }
}

extension TreeSitterCapture: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterCapture byteRange=\(byteRange.debugDescription) name=\(name) predicates=\(predicates)]"
    }
}
