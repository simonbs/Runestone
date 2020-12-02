//
//  File.swift
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

import OnigurumaBindings

protocol Rule: Codable {
    func tokenize(_ string: String) -> [Token]
}

extension Rule {
    func findAllTokens(matching regexp: OnigRegexp, in string: String) -> [Token] {
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
