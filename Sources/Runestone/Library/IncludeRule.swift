//
//  File.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import OnigurumaBindings

final class IncludeRule {
    private enum CodingKeys: CodingKey {
        case include
    }

    private let include: String

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        include = try values.decode(String.self, forKey: .include)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(include, forKey: .include)
    }
}

extension IncludeRule: Rule {
    func tokenize(_ string: String) -> [Token] {
        return []
    }
}
