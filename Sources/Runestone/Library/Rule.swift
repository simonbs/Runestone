//
//  File.swift
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

import OnigurumaBindings

protocol Rule: Codable {
    func tokenize(_ string: String) -> [Token]
}

extension Rule {
    func findAllTokens(matching regexp: OnigRegexp, in string: String) -> [Token] {
        var tokens: [Token] = []
        var start: Int32 = 0
        while let result = regexp.search(string, start: start) {
            for i in 0 ..< result.count() {
                let location = result.location(at: i)
                let length = result.length(at: i)
                let token = Token(start: location, end: location + length)
                tokens.append(token)
            }
            start = Int32(result.location(at: 0) + result.length(at: 0))
        }
        return tokens
    }
}

//enum AsdRule: Codable {
//    final class IncludeParameters: Codable {
//        private enum Key {
//            static let include = "include"
//        }
//
//        let reference: String
//
//        init(from decoder: Decoder) throws {
//            let values = try decoder.singleValueContainer()
//            let dict = try values.decode([String: String].self)
//            guard dict.keys.contains(Key.include) else {
//                let description = "\"\(Key.include)\" key not found in dictionary."
//                let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: description)
//                throw DecodingError.valueNotFound(String.self, errorContext)
//            }
//            guard let reference = dict[Key.include] else {
//                let description = "Dictionary does not contain value for \"\(Key.include)\" key."
//                let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: description)
//                throw DecodingError.valueNotFound(String.self, errorContext)
//            }
//            self.reference = reference
//        }
//
//        func encode(to encoder: Encoder) throws {
//            let dict = [Key.include: reference]
//            try dict.encode(to: encoder)
//        }
//    }
//
//    final class BeginEndParameters: Codable {
//        let name: String
//        let begin: String
//        let end: String
//    }
//
//    final class PatternsParameters: Codable {
//        let patterns: [Rule]
//    }
//
//    final class MatchParameters: Codable {
//        let name: String
//        let match: String
//    }
//
//    case include(IncludeParameters)
//    case beginEnd(BeginEndParameters)
//    case patterns(PatternsParameters)
//    case match(MatchParameters)
//
//    private var parameters: Codable {
//        switch self {
//        case .include(let parameters):
//            return parameters
//        case .beginEnd(let parameters):
//            return parameters
//        case .patterns(let parameters):
//            return parameters
//        case .match(let parameters):
//            return parameters
//        }
//    }
//
//    init(from decoder: Decoder) throws {
//        if let parameters = try? IncludeParameters(from: decoder) {
//            self = .include(parameters)
//        } else if let parameters = try? BeginEndParameters(from: decoder) {
//            self = .beginEnd(parameters)
//        } else if let parameters = try? PatternsParameters(from: decoder) {
//            self = .patterns(parameters)
//        } else if let parameters = try? MatchParameters(from: decoder) {
//            self = .match(parameters)
//        } else {
//            let description = "Unsupported type of rule or the rule doesn't have the expected parameters."
//            let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: description)
//            throw DecodingError.dataCorrupted(errorContext)
//        }
//    }
//
//    func encode(to encoder: Encoder) throws {
//        try parameters.encode(to: encoder)
//    }
//}
