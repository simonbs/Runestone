//
//  FontTraits.swift
//  
//
//  Created by Simon on 18/01/2022.
//

import Foundation

/// Traits to be applied to a font.
public struct FontTraits: OptionSet {
    public static let bold = FontTraits(rawValue: 1 << 0)
    public static let italic = FontTraits(rawValue: 1 << 1)

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
