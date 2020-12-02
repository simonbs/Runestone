//
//  File.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import OnigurumaBindings

final class BeginEndRule: Codable {
    private enum CodingKeys: CodingKey {
        case name
        case begin
        case end
        case patterns
    }

    private final class BeginEndExpressions: Codable {
        private enum CodingKeys: CodingKey {
            case begin
            case end
        }

        let begin: String
        let end: String
        let beginRegexp: OnigRegexp
        let endRegexp: OnigRegexp

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            begin = try values.decode(String.self, forKey: .begin)
            end = try values.decode(String.self, forKey: .end)
            beginRegexp = try OnigRegexp.compile(begin)
            endRegexp = try OnigRegexp.compile(end)
        }
    }

    private let name: String?
    private let beginEndExpressions: BeginEndExpressions?
    private let patterns: [Rule]?

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        patterns = try values.decodeWrappedValues([CodableRule].self, forKey: .patterns)
        if values.contains(.begin) && values.contains(.end) {
            beginEndExpressions = try BeginEndExpressions(from: decoder)
        } else if values.contains(.begin) {
            let message = "Begin/end rule contains a \(CodingKeys.begin.stringValue) key but contains no \(CodingKeys.end.stringValue) key."
            throw DecodingError.dataCorruptedError(forKey: .end, in: values, debugDescription: message)
        } else if values.contains(.end) {
            let message = "Begin/end rule contains a \(CodingKeys.end.stringValue) key but contains no \(CodingKeys.begin.stringValue) key."
            throw DecodingError.dataCorruptedError(forKey: .end, in: values, debugDescription: message)
        } else {
            beginEndExpressions = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(name, forKey: .name)
        try values.encodeWrappedValues(patterns, to: [CodableRule].self, forKey: .patterns)
        try beginEndExpressions?.encode(to: encoder)
    }
}

extension BeginEndRule: Rule {
    func tokenize(_ string: String) -> [Token] {
        return []
    }
}

