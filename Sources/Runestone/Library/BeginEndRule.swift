//
//  File.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import OnigurumaBindings

final class BeginEndRule {
    private enum CodingKeys: CodingKey {
        case name
        case begin
        case end
        case patterns
    }

    private let name: String?
    private let begin: String?
    private let end: String?
    private let patterns: [Rule]?
    private let beginRegexp: OnigRegexp?
    private let endRegexp: OnigRegexp?

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        begin = try values.decodeIfPresent(String.self, forKey: .begin)
        end = try values.decodeIfPresent(String.self, forKey: .end)
        patterns = try values.decodeWrappedValuesIfPresent([CodableRule].self, forKey: .patterns)
        if let begin = begin {
            beginRegexp = try OnigRegexp.compile(begin)
        } else {
            beginRegexp = nil
        }
        if let end = end {
            endRegexp = try OnigRegexp.compile(end)
        } else {
            endRegexp = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(name, forKey: .name)
        try values.encode(begin, forKey: .begin)
        try values.encode(end, forKey: .end)
        try values.encodeWrappedValues(patterns, to: [CodableRule].self, forKey: .patterns)
    }
}

extension BeginEndRule: Rule {
    func tokenize(_ string: String) -> [Token] {
        return []
    }
}

