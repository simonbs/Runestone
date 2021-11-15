//
//  HighlightedRange.swift
//  
//
//  Created by Simon on 03/10/2021.
//

import UIKit

public final class HighlightedRange {
    public let id: String
    public let range: NSRange
    public let color: UIColor

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
