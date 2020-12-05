//
//  File.swift
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

import OnigurumaBindings

public final class Tokenizer {
    private let language: Language
    private let ruleStack = RuleStack()

    init(language: Language) {
        self.language = language
    }

    func tokenize(_ string: String) -> [Token] {
        let tokenizationContext = TokenizationContext(ruleStack: ruleStack)
        if let scopeRule = ruleStack.lastRule {
            let tokenizationResult = scopeRule.tokenize(string, context: tokenizationContext)
            switch tokenizationResult.scopeChange {
            case .none:
                break
            case .push:
                ruleStack.push(scopeRule)
            case .pop:
                let rule = ruleStack.popLast()
                if rule !== scopeRule {
                    fatalError("The popped rule doesn't match the active rule.")
                }
            }
            print(tokenizationResult.tokens)
            return tokenizationResult.tokens
        } else {
            var allTokens: [Token] = []
            for pattern in language.patterns {
                let tokenizationResult = pattern.tokenize(string, context: tokenizationContext)
                allTokens.append(contentsOf: tokenizationResult.tokens)
                switch tokenizationResult.scopeChange {
                case .none:
                    break
                case .push:
                    ruleStack.push(pattern)
                case .pop:
                    fatalError("We don't have a rule pushed, so popping a scope doesn't make sense.")
                }
            }
            print(allTokens)
            return allTokens
        }
    }
}
