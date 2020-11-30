//
//  File.swift
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

import OnigurumaBindings

public enum OnigRegexpError: LocalizedError {
    case failedCompiling(Error)

    public var errorDescription: String? {
        switch self {
        case .failedCompiling(let error):
            return "Failed compiling regular expression. \(error.localizedDescription)"
        }
    }
}

extension OnigRegexp {
    static func compile(_ expression: String) -> Result<OnigRegexp, OnigRegexpError> {
        do {
            let regexp: OnigRegexp = try OnigRegexp.compile(expression)
            return .success(regexp)
        } catch {
            return .failure(.failedCompiling(error))
        }
    }
}
