//
//  Language.swift
//  
//
//  Created by Simon Støvring on 12/02/2021.
//

import TreeSitter
import RunestoneTreeSitter

public struct TreeSitterLanguage {
    public let language: UnsafePointer<TSLanguage>
}

public final class Language {
    let languagePointer: UnsafePointer<TSLanguage>
    let encoding: TextEncoding
    let highlightsQuery: TreeSitterHighlightsQuery?

    public init(_ language: UnsafePointer<TSLanguage>, encoding: TextEncoding, highlightsQuery: TreeSitterHighlightsQuery? = nil) {
        self.languagePointer = language
        self.encoding = encoding
        self.highlightsQuery = highlightsQuery
    }
}
