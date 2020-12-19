//
//  Node.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

public final class Node {
    let rawValue: TSNode
    public var expressionString: String? {
        if let str = ts_node_string(rawValue) {
            let result = String(cString: str)
            str.deallocate()
            return result
        } else {
            return nil
        }
    }
    public var type: String? {
        if let str = ts_node_type(rawValue) {
            return String(cString: str)
        } else {
            return nil
        }
    }
    public var startByte: uint {
        return ts_node_start_byte(rawValue)
    }
    public var endByte: uint {
        return ts_node_end_byte(rawValue)
    }

    init(node: TSNode) {
        self.rawValue = node
    }
}

extension Node: Hashable {
    public static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.rawValue.id == rhs.rawValue.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue.id)
    }
}
