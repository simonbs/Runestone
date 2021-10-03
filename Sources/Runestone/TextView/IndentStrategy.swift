//
//  IndentStrategy.swift
//  
//
//  Created by Simon Støvring on 07/03/2021.
//

import Foundation

public enum IndentStrategy: Equatable {
    case tab(length: Int)
    case space(length: Int)
}

public enum DetectedIndentStrategy {
    case tab
    case space(length: Int)
    case unknown
}

extension IndentStrategy {
    var tabLength: Int {
        switch self {
        case .tab(let length):
            return length
        case .space(let length):
            return length
        }
    }

    func string(indentLevel: Int) -> String {
        switch self {
        case .tab:
            return String(repeating: Symbol.Character.tab, count: indentLevel)
        case .space(let length):
            return String(repeating: Symbol.Character.space, count: length * indentLevel)
        }
    }
}
