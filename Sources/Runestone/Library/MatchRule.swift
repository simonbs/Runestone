//
//  File.swift
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

import OnigurumaBindings

final class MatchRule {
    private enum CodingKeys: CodingKey {
        case name
        case match
    }

    private let name: String
    private let match: String
    private let regexp: OnigRegexp

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        match = try values.decode(String.self, forKey: .match)
        regexp = try OnigRegexp.compile(match)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(name, forKey: .name)
        try values.encode(match, forKey: .match)
    }
}

extension MatchRule: Rule {
    func tokenize(_ string: String) -> [Token] {
        return findAllTokens(matching: regexp, in: string)
    }
}
