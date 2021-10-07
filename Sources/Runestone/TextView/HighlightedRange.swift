//
//  HighlightedRange.swift
//  
//
//  Created by Simon on 03/10/2021.
//

import UIKit

public final class HighlightedRange {
    public let range: NSRange
    public let color: UIColor

    public init(range: NSRange, color: UIColor) {
        self.range = range
        self.color = color
    }
}

extension HighlightedRange: Equatable {
    public static func == (lhs: HighlightedRange, rhs: HighlightedRange) -> Bool {
        return lhs.range == rhs.range && lhs.color == rhs.color
    }
}

extension HighlightedRange: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[HighightedRange range=\(range)]"
    }
}
