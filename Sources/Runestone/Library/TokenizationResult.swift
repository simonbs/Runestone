//
//  File.swift
//  
//
//  Created by Simon Støvring on 02/12/2020.
//

import Foundation

enum TokenizationScopeChange {
    case none
    case push
    case pop
}

final class TokenizationResult {
    let tokens: [Token]
    let scopeChange: TokenizationScopeChange

    init(tokens: [Token], scopeChange: TokenizationScopeChange) {
        self.tokens = tokens
        self.scopeChange = scopeChange
    }
}
