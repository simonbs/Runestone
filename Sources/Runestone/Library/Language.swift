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
    let scopeName: String
    let patterns: [Rule]
    let repository: [String: Rule]
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
