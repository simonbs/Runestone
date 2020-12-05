//
//  File.swift
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

import OnigurumaBindings

protocol Rule: class, Codable {
    var isPrepared: Bool { get }
    var scopeHandlingRule: Rule { get }
    func prepare(repository: RuleRepository)
    func tokenize(_ string: String, context: TokenizationContext) -> TokenizationResult
}

extension Rule {
    var scopeHandlingRule: Rule {
        return self
    }
}
