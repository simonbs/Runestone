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

extension TreeSitterIndentationScopes: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[TreeSitterIndentationScopes indent=\(indent) inheritIndent=\(inheritIndent) outdent=\(outdent) indentScanLocation=\(indentScanLocation)]"
    }
}

extension TreeSitterIndentationScopes.IndentScanLocation: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .caret:
            return "caret"
        case .lineStart:
            return "lineStart"
        }
    }
}
