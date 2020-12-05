//
//  File.swift
//  
//
//  Created by Simon Støvring on 02/12/2020.
//

import Foundation

final class Token {
    let name: String
    let start: UInt
    let end: UInt
    let contents: String?
    var range: NSRange {
        return NSMakeRange(Int(start), Int(end - start))
    }

    init(name: String, start: UInt, end: UInt, contents: String?) {
        self.name = name
        self.start = start
        self.end = end
        self.contents = contents
    }
}

extension Token: CustomDebugStringConvertible {
    var debugDescription: String {
        if let contents = contents {
            return "\(contents) (\(start) - \(end), \(name))"
        } else {
            return "(\(start) - \(end), \(name))"
        }
    }
}
