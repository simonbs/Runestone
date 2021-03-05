//
//  TreeSitterIndentationScopes.swift
//  
//
//  Created by Simon Støvring on 01/03/2021.
//

import Foundation

public final class TreeSitterIndentationScopes {
    public let indent: [String]
    public let outdent: [String]

    public init(indent: [String] = [], outdent: [String] = []) {
        self.indent = indent
        self.outdent = outdent
    }
}
