//
//  TreeSitterLanguage.swift
//  
//
//  Created by Simon Støvring on 12/02/2021.
//

import TreeSitter

public enum TreeSitterTextEncoding {
    case utf8
    case utf16
}

public extension TreeSitterTextEncoding {
    var tsEncoding: TSInputEncoding {
        switch self {
        case .utf8:
            return TSInputEncodingUTF8
        case .utf16:
            return TSInputEncodingUTF16
        }
    }
}

public final class TreeSitterLanguage {
    let languagePointer: UnsafePointer<TSLanguage>
    let textEncoding: TreeSitterTextEncoding
    let highlightsQuery: TreeSitterHighlightsQuery?

    public init(_ language: UnsafePointer<TSLanguage>, textEncoding: TreeSitterTextEncoding, highlightsQuery: TreeSitterHighlightsQuery? = nil) {
        self.languagePointer = language
        self.textEncoding = textEncoding
        self.highlightsQuery = highlightsQuery
    }
}
