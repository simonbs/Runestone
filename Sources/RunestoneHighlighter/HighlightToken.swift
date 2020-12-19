//
//  File.swift
//  
//
//  Created by Simon Støvring on 19/12/2020.
//

import Foundation

@objc public final class HighlightToken: NSObject {
    @objc public let range: NSRange
    @objc public let name: String

    init(range: NSRange, name: String) {
        self.range = range
        self.name = name
    }
}
