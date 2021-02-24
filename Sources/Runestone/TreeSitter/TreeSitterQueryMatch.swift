//
//  TreeSitterQueryMatch.swift
//  
//
//  Created by Simon Støvring on 23/02/2021.
//

import TreeSitter

final class TreeSitterQueryMatch {
    let captures: [TreeSitterCapture]

    init(captures: [TreeSitterCapture]) {
        self.captures = captures
    }

    func capture(forIndex index: UInt32) -> TreeSitterCapture? {
        return captures.first(where: { $0.index == index })
    }
}
