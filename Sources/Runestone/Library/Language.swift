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
    private enum CodingKeys: CodingKey {
        case patterns
        case repository
    }

    let patterns: [Rule]
    let repository: [String: Rule]

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let codablePatterns = try values.decode([CodableRule].self, forKey: .patterns)
        let codableRepository = try values.decode([String: CodableRule].self, forKey: .repository)
        patterns = codablePatterns.map(\.rule)
        repository = Dictionary(uniqueKeysWithValues: codableRepository.map { ($0, $1.rule) })
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        let codablePatterns = patterns.map(CodableRule.init)
        let codableRepository = Dictionary(uniqueKeysWithValues: repository.map { ($0, CodableRule($1)) })
        try values.encode(codablePatterns, forKey: .patterns)
        try values.encode(codableRepository, forKey: .repository)
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
