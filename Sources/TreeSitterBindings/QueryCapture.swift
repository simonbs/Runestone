//
//  QueryCapture.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation

final class QueryCapture {
    let node: Node
    let index: UInt32
    let name: String

    init(node: Node, index: UInt32, name: String) {
        self.node = node
        self.index = index
        self.name = name
    }
}
