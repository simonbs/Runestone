//
//  Language.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter

public final class Language {
    public final class Query {
        let fileURL: URL?
        private(set) var string: String?
        private var isPrepared = false

        public init(fileURL: URL) {
            self.fileURL = fileURL
        }

        public init(string: String) {
            self.fileURL = nil
            self.string = string
        }

        public func prepare() {
            if !isPrepared {
                isPrepared = true
                if string == nil, let fileURL = fileURL {
                    string = try? String(contentsOf: fileURL)
                }
            }
        }
    }

    let pointer: UnsafePointer<TSLanguage>
    let highlightsQuery: Query

    public init(_ treeSitterLanguage: UnsafePointer<TSLanguage>, highlightsQuery: Query) {
        self.pointer = treeSitterLanguage
        self.highlightsQuery = highlightsQuery
    }
}
