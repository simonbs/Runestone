//
//  File.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import Foundation

public enum LanguageError: LocalizedError {
    case decodingError(DecodingError)
    case unknownError(Error)

    public var errorDescription: String? {
        switch self {
        case .decodingError(let error):
            return error.localizedDescription
        case .unknownError(let error):
            return error.localizedDescription
        }
    }
}

public final class Language: Codable {
    public let scopeName: String
    public let patterns: [Rule]
    public let repository: [String: Rule]
}

public extension Language {
    enum Rule: Codable {
        public final class IncludeParameters: Codable {
            private enum Key {
                static let include = "include"
            }

            public let reference: String

            public init(from decoder: Decoder) throws {
                let values = try decoder.singleValueContainer()
                let dict = try values.decode([String: String].self)
                guard dict.keys.contains(Key.include) else {
                    let description = "\"\(Key.include)\" key not found in dictionary."
                    let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: description)
                    throw DecodingError.valueNotFound(String.self, errorContext)
                }
                guard let reference = dict[Key.include] else {
                    let description = "Dictionary does not contain value for \"\(Key.include)\" key."
                    let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: description)
                    throw DecodingError.valueNotFound(String.self, errorContext)
                }
                self.reference = reference
            }

            public func encode(to encoder: Encoder) throws {
                let dict = [Key.include: reference]
                try dict.encode(to: encoder)
            }
        }

        public final class BeginEndParameters: Codable {
            public let name: String
            public let begin: String
            public let end: String
        }

        public final class PatternsParameters: Codable {
            public let patterns: [Rule]
        }

        public final class MatchParameters: Codable {
            public let name: String
            public let match: String
        }

        case include(IncludeParameters)
        case beginEnd(BeginEndParameters)
        case patterns(PatternsParameters)
        case match(MatchParameters)

        private var parameters: Codable {
            switch self {
            case .include(let parameters):
                return parameters
            case .beginEnd(let parameters):
                return parameters
            case .patterns(let parameters):
                return parameters
            case .match(let parameters):
                return parameters
            }
        }

        public init(from decoder: Decoder) throws {
            if let parameters = try? IncludeParameters(from: decoder) {
                self = .include(parameters)
            } else if let parameters = try? BeginEndParameters(from: decoder) {
                self = .beginEnd(parameters)
            } else if let parameters = try? PatternsParameters(from: decoder) {
                self = .patterns(parameters)
            } else if let parameters = try? MatchParameters(from: decoder) {
                self = .match(parameters)
            } else {
                let description = "Unsupported type of rule or the rule doesn't have the expected parameters."
                let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: description)
                throw DecodingError.dataCorrupted(errorContext)
            }
        }

        public func encode(to encoder: Encoder) throws {
            try parameters.encode(to: encoder)
        }
    }
}

public extension Language {
    static func fromFile(at fileURL: URL) -> Result<Language, LanguageError> {
        do {
            let data = try Data(contentsOf: fileURL)
            return from(data)
        } catch {
            return .failure(.unknownError(error))
        }
    }

    static func from(_ data: Data) -> Result<Language, LanguageError> {
        do {
            let decoder = PropertyListDecoder()
            let language = try decoder.decode(Language.self, from: data)
            return .success(language)
        } catch let error as DecodingError {
            return .failure(.decodingError(error))
        } catch {
            return .failure(.unknownError(error))
        }
    }
}
