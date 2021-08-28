//
//  SearchQuery.swift
//  
//
//  Created by Simon on 25/08/2021.
//

import Foundation

public struct SearchQuery: Hashable, Equatable {
    public enum Option {
        case regularExpression
        case caseSensitive
    }

    public let text: String
    public let isRegularExpression: Bool
    public let isCaseSensitive: Bool

    private var regularExpressionOptions: NSRegularExpression.Options {
        var options: NSRegularExpression.Options = []
        if isRegularExpression {
            options.insert(.anchorsMatchLines)
        } else {
            options.insert(.ignoreMetacharacters)
        }
        if !isCaseSensitive {
            options.insert(.caseInsensitive)
        }
        return options
    }

    public init(text: String, isRegularExpression: Bool = false, isCaseSensitive: Bool = false) {
        self.text = text
        self.isRegularExpression = isRegularExpression
        self.isCaseSensitive = isCaseSensitive
    }

    func makeRegularExpression() throws -> NSRegularExpression {
        return try NSRegularExpression(pattern: text, options: regularExpressionOptions)
    }
}
