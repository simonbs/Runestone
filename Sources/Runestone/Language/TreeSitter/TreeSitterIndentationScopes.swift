//
//  TreeSitterIndentationScopes.swift
//  
//
//  Created by Simon Støvring on 01/03/2021.
//

import Foundation

public final class TreeSitterIndentationScopes {
    public final class Types {
        public let indent: [String]
        public let outdent: [String]

        public init(indent: [String] = [], outdent: [String] = []) {
            self.indent = indent
            self.outdent = outdent
        }
    }

    public let indent: [String]
    public let indentExceptFirst: [String]
    public let indentExceptFirstOrBlock: [String]
    public let types: Types
    public let indentsAddingAdditionalLineBreak: [String]

    public init(
        indent: [String] = [],
        indentExceptFirst: [String] = [],
        indentExceptFirstOrBlock: [String] = [],
        types: Types = .init(),
        indentsAddingAdditionalLineBreak: [String] = []) {
        self.indent = indent
        self.indentExceptFirst = indentExceptFirst
        self.indentExceptFirstOrBlock = indentExceptFirstOrBlock
        self.types = types
        self.indentsAddingAdditionalLineBreak = indentsAddingAdditionalLineBreak
    }
}
