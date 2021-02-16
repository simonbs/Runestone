//
//  TreeSitterLanguage.swift
//  
//
//  Created by Simon Støvring on 12/02/2021.
//

import Foundation
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

public protocol TreeSitterLanguageProvider: AnyObject {
    func treeSitterLanguage(named languageName: String) -> TreeSitterLanguage?
}

public final class TreeSitterLanguage {
    let languagePointer: UnsafePointer<TSLanguage>
    let textEncoding: TreeSitterTextEncoding
    let highlightsQuery: TreeSitterQuery?
    let injectionsQuery: TreeSitterQuery?
    private(set) weak var injectedLanguageProvider: TreeSitterLanguageProvider?

    public init(
        _ language: UnsafePointer<TSLanguage>,
        textEncoding: TreeSitterTextEncoding,
        highlightsQuery: Query? = nil,
        injectionsQuery: Query? = nil,
        injectedLanguageProvider: TreeSitterLanguageProvider? = nil) {
        self.languagePointer = language
        self.textEncoding = textEncoding
        self.highlightsQuery = highlightsQuery?.createQuery(with: language)
        self.injectionsQuery = injectionsQuery?.createQuery(with: language)
        self.injectedLanguageProvider = injectedLanguageProvider
    }
}

extension TreeSitterLanguage {
    public final class Query {
        let string: String?

        public init?(contentsOf fileURL: URL) {
            string = try? String(contentsOf: fileURL)
        }

        public init(string: String) {
            self.string = string
        }

        func createQuery(with language: UnsafePointer<TSLanguage>) -> TreeSitterQuery? {
            if let string = string {
                return try? TreeSitterQuery(source: string, language: language)
            } else {
                return nil
            }
        }
    }
}
