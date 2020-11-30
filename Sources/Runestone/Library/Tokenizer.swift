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
    private let regexp: OnigRegexp

    init(language: Language) {
        self.language = language
        self.regexp = try! OnigRegexp.compile("(?x)-?(?:0|[1-9]\\d*)(?:(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)?")
    }

    func tokenize(_ string: String) -> [Token] {
        return findAllTokens(matching: regexp, in: string)
    }
}

private extension Tokenizer {
    private func findAllTokens(matching regexp: OnigRegexp, in string: String) -> [Token] {
        var tokens: [Token] = []
        var start: Int32 = 0
        while let result = regexp.search(string, start: start) {
            for i in 0 ..< result.count() {
                let location = result.location(at: i)
                let length = result.length(at: i)
                let token = Token(start: location, end: location + length)
                tokens.append(token)
            }
            start = Int32(result.location(at: 0) + result.length(at: 0))
        }
        return tokens
    }
}
