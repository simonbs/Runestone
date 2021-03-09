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
    public let outdent: [String]
    public let indentsAddingAdditionalLineBreak: [String]

    public init(
        indentIsDeterminedByLineStart: Bool = false,
        indent: [String] = [],
        outdent: [String] = [],
        indentsAddingAdditionalLineBreak: [String] = []) {
        self.indentIsDeterminedByLineStart = indentIsDeterminedByLineStart
        self.indent = indent
        self.outdent = outdent
        self.indentsAddingAdditionalLineBreak = indentsAddingAdditionalLineBreak
    }
}
