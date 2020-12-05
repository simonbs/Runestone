//
//  File.swift
//  
//
//  Created by Simon Støvring on 02/12/2020.
//

import Foundation

final class RuleRepository: Codable {
    private let repository: [String: Rule]

    public init(from decoder: Decoder) throws {
        let valueContainer = try decoder.singleValueContainer()
        repository = try valueContainer.decodeWrappedValues([String: CodableRule].self)
    }

    public func encode(to encoder: Encoder) throws {
        var valueContainer = encoder.singleValueContainer()
        try valueContainer.encodeWrappedValues(repository, to: [String: CodableRule].self)
    }

    public func prepare() {
        let allRules = repository.values
        for rule in allRules {
            rule.prepare(repository: self)
        }
    }

    public func rule(named name: String) -> Rule? {
        return repository[name]
    }
}
