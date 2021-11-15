//
//  SearchReplaceResult.swift
//  
//
//  Created by Simon on 11/10/2021.
//

import Foundation

public struct SearchReplaceResult: Hashable, Equatable {
    public let id: String = UUID().uuidString
    public let range: NSRange
    public let startLinePosition: LinePosition
    public let endLinePosition: LinePosition
    public let replacementText: String
}
