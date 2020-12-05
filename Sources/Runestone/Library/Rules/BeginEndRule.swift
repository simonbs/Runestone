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
        case beginCaptures
        case endCaptures
        case captures
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

    private(set) var isPrepared = false

    private let beginEndExpressions: BeginEndExpressions?
    private let patterns: [Rule]?
    private let beginCaptures: CaptureCollection?
    private let endCaptures: CaptureCollection?
    private let captures: CaptureCollection?
    private let allBeginCaptures: CaptureCollection?
    private let allEndCaptures: CaptureCollection?

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        patterns = try values.decodeWrappedValuesIfPresent([CodableRule].self, forKey: .patterns)
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
        let beginCaptures = try values.decodeIfPresent(CaptureCollection.self, forKey: .beginCaptures)
        let endCaptures = try values.decodeIfPresent(CaptureCollection.self, forKey: .endCaptures)
        let captures = try values.decodeIfPresent(CaptureCollection.self, forKey: .captures)
        self.beginCaptures = beginCaptures
        self.endCaptures = endCaptures
        self.captures = captures
        if let captures = captures, let beginCaptures = beginCaptures {
            allBeginCaptures = captures.concat(beginCaptures)
        } else {
            allBeginCaptures = captures ?? beginCaptures
        }
        if let captures = captures, let endCaptures = endCaptures {
            allEndCaptures = captures.concat(endCaptures)
        } else {
            allEndCaptures = captures ?? endCaptures
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeWrappedValues(patterns, to: [CodableRule].self, forKey: .patterns)
        try values.encode(beginCaptures, forKey: .beginCaptures)
        try values.encode(endCaptures, forKey: .endCaptures)
        try values.encode(captures, forKey: .captures)
        try beginEndExpressions?.encode(to: encoder)
    }
}

extension BeginEndRule: Rule {
    func prepare(repository: RuleRepository) {
        if !isPrepared {
            isPrepared = true
            if let patterns = patterns {
                for pattern in patterns {
                    pattern.prepare(repository: repository)
                }
            }
        }
    }

    func tokenize(_ string: String, context: TokenizationContext) -> TokenizationResult {
        if context.ruleStack.isRuleInScope(self) {
            var tokens: [Token] = []
            if let patterns = patterns {
                for pattern in patterns {
                    let tokenizationResult = pattern.tokenize(string, context: context)
                    tokens.append(contentsOf: tokenizationResult.tokens)
                    switch tokenizationResult.scopeChange {
                    case .none:
                        break
                    case .push:
                        context.ruleStack.push(pattern)
                    case .pop:
                        fatalError("We don't have a rule pushed, so popping a scope doesn't make sense.")
                    }
                }
            }
            if let match = beginEndExpressions?.endRegexp.search(string) {
                return TokenizationResult(tokens: tokens, scopeChange: .pop)
            } else {
                return TokenizationResult(tokens: tokens, scopeChange: .none)
            }
        } else if let beginEndExpressions = beginEndExpressions {
            if let match = beginEndExpressions.beginRegexp.search(string) {
                var tokens: [Token] = []
                if let captures = allBeginCaptures {
                    for captureGroupIndex in 0 ..< match.count() {
                        if let capture = captures.capture(at: Int(captureGroupIndex)) {
                            let location = match.location(at: captureGroupIndex)
                            let length = match.length(at: captureGroupIndex)
                            let contents = match.string(at: captureGroupIndex)
                            let token = Token(name: capture.name, start: location, end: location + length, contents: contents)
                            tokens.append(token)
                        }
                    }
                }
                return TokenizationResult(tokens: tokens, scopeChange: .push)
            } else {
                return TokenizationResult(tokens: [], scopeChange: .none)
            }
        } else if let patterns = patterns {
            var tokens: [Token] = []
            for pattern in patterns {
                let tokenizationResult = pattern.tokenize(string, context: context)
                tokens.append(contentsOf: tokenizationResult.tokens)
                switch tokenizationResult.scopeChange {
                case .none:
                    break
                case .push:
                    context.ruleStack.push(pattern)
                case .pop:
                    fatalError("We don't have a rule pushed, so popping a scope doesn't make sense.")
                }
            }
            return TokenizationResult(tokens: tokens, scopeChange: .none)
        } else {
            return TokenizationResult(tokens: [], scopeChange: .none)
        }
    }
}
