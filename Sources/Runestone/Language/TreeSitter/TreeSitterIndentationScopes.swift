//
//  TreeSitterIndentationScopes.swift
//  
//
//  Created by Simon Støvring on 01/03/2021.
//

import Foundation

public final class TreeSitterIndentationScopes {
    public enum IndentScanLocation {
        case caret
        case lineStart
    }

    public let indent: [String]
    public let inheritIndent: [String]
    public let outdent: [String]
    public let indentScanLocation: IndentScanLocation

    public init(
        indent: [String] = [],
        inheritIndent: [String] = [],
        outdent: [String] = [],
        indentScanLocation: IndentScanLocation = .caret) {
        self.indent = indent
        self.inheritIndent = inheritIndent
        self.outdent = outdent
        self.indentScanLocation = indentScanLocation
    }
}
