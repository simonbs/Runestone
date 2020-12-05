//
//  File.swift
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

import OnigurumaBindings

final class MatchRule: Codable {
    private enum CodingKeys: CodingKey {
        case name
        case match
    }

    private(set) var isPrepared = false

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
    func prepare(repository: RuleRepository) {
        isPrepared = true
    }

    func tokenize(_ string: String, context: TokenizationContext) -> TokenizationResult {
        var tokens: [Token] = []
        var start: Int32 = 0
        while let result = regexp.search(string, start: start) {
            for i in 0 ..< result.count() {
                let location = result.location(at: i)
                let length = result.length(at: i)
                let contents = result.string(at: i)
                let token = Token(name: name, start: location, end: location + length, contents: contents)
                tokens.append(token)
            }
            start = Int32(result.location(at: 0) + result.length(at: 0))
        }
        return TokenizationResult(tokens: tokens, scopeChange: .none)
    }
}
