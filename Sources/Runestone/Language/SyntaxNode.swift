//
//  SyntaxNode.swift
//  
//
//  Created by Simon Støvring on 25/02/2021.
//

import Foundation

public struct SyntaxNode {
    public let type: String
    public let startPosition: LinePosition
    public let endPosition: LinePosition
}
