//
//  TreeSitterIndentationScopes.swift
//  
//
//  Created by Simon Støvring on 01/03/2021.
//

import Foundation

public final class TreeSitterIndentationScopes {
    public let indentIsDeterminedByLineStart: Bool
    public let indent: [String]
    public let inheritIndent: [String]
    public let outdent: [String]
    public let indentsAddingAdditionalLineBreak: [String]

    public init(
        indentIsDeterminedByLineStart: Bool = false,
        indent: [String] = [],
        inheritIndent: [String] = [],
        outdent: [String] = [],
        indentsAddingAdditionalLineBreak: [String] = []) {
        self.indentIsDeterminedByLineStart = indentIsDeterminedByLineStart
        self.indent = indent
        self.inheritIndent = inheritIndent
        self.outdent = outdent
        self.indentsAddingAdditionalLineBreak = indentsAddingAdditionalLineBreak
    }
}
