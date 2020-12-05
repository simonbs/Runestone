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
    let repository: RuleRepository

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        patterns = try values.decodeWrappedValues([CodableRule].self, forKey: .patterns)
        repository = try values.decode(RuleRepository.self, forKey: .repository)
        prepare()
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeWrappedValues(patterns, to: [CodableRule].self, forKey: .patterns)
        try repository.encode(to: encoder)
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

private extension Language {
    private func prepare() {
        repository.prepare()
        for pattern in patterns {
            pattern.prepare(repository: repository)
        }
    }
}
