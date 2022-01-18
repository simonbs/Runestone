//
//  SearchQuery.swift
//  
//
//  Created by Simon on 25/08/2021.
//

import Foundation

/// Query to search for in the text view.
///
/// Use the options on the query to specify if the text is a regular expression and if the query should be case sensitive or not.
///
/// When the query contains a regular expression the capture groups can be referred in a replacement text using $0, $1, $2 etc.
public struct SearchQuery: Hashable, Equatable {
    /// The text to search for. May be a regular expression if `isRegularExpression` is `true`.
    public let text: String
    /// Whether the text is a regular exprssion.
    public let isRegularExpression: Bool
    /// Whether to perform a case-sensitive search.
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
