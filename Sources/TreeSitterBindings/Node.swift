//
//  Node.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

final class Node {
    let rawValue: TSNode
    var expressionString: String? {
        if let str = ts_node_string(rawValue) {
            let result = String(cString: str)
            str.deallocate()
            return result
        } else {
            return nil
        }
    }
    var type: String? {
        if let str = ts_node_type(rawValue) {
            return String(cString: str)
        } else {
            return nil
        }
    }

    init(node: TSNode) {
        self.rawValue = node
    }
}
