//
//  SearchResult.swift
//  
//
//  Created by Simon on 26/08/2021.
//

import Foundation

public struct SearchResult: Hashable, Equatable {
    public let range: NSRange
    public let firstLineLocalRange: NSRange
    public let startLinePosition: LinePosition
    public let endLinePosition: LinePosition
}
