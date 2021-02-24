//
//  TreeSitterPredicate.swift
//  
//
//  Created by Simon Støvring on 15/02/2021.
//

import Foundation

final class TreeSitterPredicate {
    enum Step {
        case capture(UInt32)
        case string(String)
    }

    let name: String
    let steps: [Step]

    init(name: String, steps: [Step]) {
        self.name = name
        self.steps = steps
    }
}

extension TreeSitterPredicate: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterPredicate name=\(name) steps=\(steps)]"
    }
}

extension TreeSitterPredicate.Step: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .capture(let id):
            return "[TreeSitterPredicate.Step capture=\(id)]"
        case .string(let string):
            return "[TreeSitterPredicate.Step string=\(string)]"
        }
    }
}
