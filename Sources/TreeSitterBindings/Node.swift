//
//  File.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

final class Node {
    var expressionString: String? {
        if let cstr = ts_node_string(node) {
            let result = String(cString: cstr)
            cstr.deallocate()
            return result
        } else {
            return nil
        }
    }

    private let node: TSNode

    init(node: TSNode) {
        self.node = node
    }
}
