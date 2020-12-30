//
//  NewLineFinder.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

enum NewLineFinder {
    static func rangeOfNextNewLine(in text: NSString, startingAt location: Int) -> NSRange? {
        let range = NSRange(location: location, length: 0)
        var end: Int = NSNotFound
        var contentsEnd: Int = NSNotFound
        text.getLineStart(nil, end: &end, contentsEnd: &contentsEnd, for: range)
        if end != NSNotFound && contentsEnd != NSNotFound {
            return NSRange(location: contentsEnd, length: end - contentsEnd)
        } else {
            return nil
        }
    }
}
