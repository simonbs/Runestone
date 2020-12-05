//
//  File.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import OnigurumaBindings

final class IncludeRule: Codable {
    private enum CodingKeys: CodingKey {
        case include
    }

    private enum IncludeType: Codable {
        private enum Grammar {
            static let selfKeyword = "$self"
            static let rulePrefix = "#"
        }

        struct LanguageParameters {
            let languageName: String
        }

        struct RepositoryParameters {
            let ruleName: String
        }

        case `self`
        case repository(RepositoryParameters)
        case language(LanguageParameters)

        private var rawValue: String {
            switch self {
            case .`self`:
                return Grammar.selfKeyword
            case .repository(let parameters):
                return Grammar.rulePrefix + parameters.ruleName
            case .language(let parameters):
                return parameters.languageName
            }
        }

        public init(from decoder: Decoder) throws {
            let valueContainer = try decoder.singleValueContainer()
            let rawValue = try valueContainer.decode(String.self)
            if rawValue == Grammar.selfKeyword {
                self = .`self`
            } else if rawValue.hasPrefix(Grammar.rulePrefix) {
                let ruleName = String(rawValue[rawValue.index(rawValue.startIndex, offsetBy: 1) ..< rawValue.endIndex])
                self = .repository(RepositoryParameters(ruleName: ruleName))
            } else {
                self = .language(LanguageParameters(languageName: rawValue))
            }
        }

        func encode(to encoder: Encoder) throws {
            var values = encoder.singleValueContainer()
            try values.encode(rawValue)
        }
    }

    private(set) var isPrepared = false
    var scopeHandlingRule: Rule {
        return includedRule ?? self
    }
    
    private let include: IncludeType
    private var includedRule: Rule?

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        include = try values.decode(IncludeType.self, forKey: .include)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(include, forKey: .include)
    }
}

extension IncludeRule: Rule {
    func prepare(repository: RuleRepository) {
        if !isPrepared {
            isPrepared = true
            switch include {
            case .`self`:
                fatalError("Recursively including the language is not currently supported.")
            case .repository(let parameters):
                if let rule = repository.rule(named: parameters.ruleName) {
                    includedRule = rule
                } else {
                    fatalError("No rule named \"" + parameters.ruleName + "\" found in repository.")
                }
            case .language:
                fatalError("Including another language is not currently supported.")
            }
        }
    }

    func tokenize(_ string: String, context: TokenizationContext) -> TokenizationResult {
        if let includedRule = includedRule {
            return includedRule.tokenize(string, context: context)
        } else {
            fatalError("Included rule not available. This should have been set during the preparation phase.")
        }
    }
}
