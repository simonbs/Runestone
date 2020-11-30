//
//  File.swift
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

import OnigurumaBindings

final class Token {
    let start: UInt
    let end: UInt
    var range: NSRange {
        return NSMakeRange(Int(start), Int(end - start))
    }

    init(start: UInt, end: UInt) {
        self.start = start
        self.end = end
    }
}

public final class Tokenizer {
    private let language: Language

    init(language: Language) {
        self.language = language
    }

    func tokenize(_ string: String) -> [Token] {
        return language.patterns[0].tokenize(string)
    }
}
