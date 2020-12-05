//
//  File.swift
//  
//
//  Created by Simon Støvring on 02/12/2020.
//

import Foundation

final class RuleStack {
    var lastRule: Rule? {
        return rules.last
    }
    
    private var rules: [Rule] = []

    func push(_ rule: Rule) {
        print("Push rule")
        rules.append(rule.scopeHandlingRule)
    }

    @discardableResult
    func popLast() -> Rule? {
        print("Pop rule")
        return rules.popLast()
    }

    func isRuleInScope(_ rule: Rule) -> Bool {
        return rule === lastRule
    }
}
