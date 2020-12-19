//
//  File.swift
//  
//
//  Created by Simon Støvring on 19/12/2020.
//

import Foundation

@objc public final class HighlighterEditProcessingResult: NSObject {
    @objc public let tokens: [HighlightToken]

    init(tokens: [HighlightToken]) {
        self.tokens = tokens
    }
}
