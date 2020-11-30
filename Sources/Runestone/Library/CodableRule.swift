//
//  File.swift
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

import Foundation

struct CodableRule: Codable {
    let rule: Rule

    init(_ rule: Rule) {
        self.rule = rule
    }

    init(from decoder: Decoder) throws {
        let ruleTypes: [Rule.Type] = [MatchRule.self]
        var decodedRule: Rule?
        for ruleType in ruleTypes {
            if let rule = try? ruleType.init(from: decoder) {
                decodedRule = rule
                break
            }
        }
        if let decodedRule = decodedRule {
            rule = decodedRule
        } else {
            let description = "Unsupported type of rule or the rule doesn't have the expected parameters."
            let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: description)
            throw DecodingError.dataCorrupted(errorContext)
        }
    }

    func encode(to encoder: Encoder) throws {
        try rule.encode(to: encoder)
    }
}

