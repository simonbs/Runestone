//
//  HighlightedRange.swift
//  
//
//  Created by Simon on 03/10/2021.
//

import UIKit

/// Range of text to highlight.
public final class HighlightedRange {
    /// Unique identifier of the highlighted range.
    public let id: String
    /// Range in the text to highlight.
    public let range: NSRange
    /// Color to highlight the text with.
    public let color: UIColor

    /// Create a new highlighted range.
    /// - Parameters:
    ///   - id: ID of the range. Defaults to a UUID.
    ///   - range: Range in the text to highlight.
    ///   - color: Color to highlight the text with.
    public init(id: String = UUID().uuidString, range: NSRange, color: UIColor) {
        self.id = id
        self.range = range
        self.color = color
    }
}

extension HighlightedRange: Equatable {
    public static func == (lhs: HighlightedRange, rhs: HighlightedRange) -> Bool {
        return lhs.id == rhs.id && lhs.range == rhs.range && lhs.color == rhs.color
    }
}

extension HighlightedRange: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[HighightedRange range=\(range)]"
    }
}
