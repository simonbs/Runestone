//
//  File.swift
//  
//
//  Created by Simon Støvring on 02/12/2020.
//

import Foundation

public final class TokenizationContext {
    let ruleStack: RuleStack

    init(ruleStack: RuleStack) {
        self.ruleStack = ruleStack
    }
}
