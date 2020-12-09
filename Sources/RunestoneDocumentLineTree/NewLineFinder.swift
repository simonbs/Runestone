//
//  NewLineFinder.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

enum NewLineFinder {
    static func rangeOfNextNewLine(in text: NSString, startingAt location: Int) -> NSRange? {
        let substring = text.substring(with: NSRange(location: location, length: text.length - location)) as NSString
        let rangeOfCarriageReturn = substring.range(of: NewLineSymbol.carriageReturn)
        if rangeOfCarriageReturn.location != NSNotFound {
            if rangeOfCarriageReturn.location < substring.length - 1 {
                let nextCharacterRange = NSMakeRange(rangeOfCarriageReturn.location + 1, 1)
                if substring.substring(with: nextCharacterRange) == NewLineSymbol.lineFeed {
                    let totalLength = rangeOfCarriageReturn.length + nextCharacterRange.length
                    return NSRange(location: location + rangeOfCarriageReturn.location, length: totalLength)
                } else {
                    return NSRange(location: location + rangeOfCarriageReturn.location, length: rangeOfCarriageReturn.length)
                }
            } else {
                return NSRange(location: location + rangeOfCarriageReturn.location, length: rangeOfCarriageReturn.length)
            }
        } else {
            let rangeOfLineFeed = substring.range(of: NewLineSymbol.lineFeed)
            if rangeOfLineFeed.location != NSNotFound {
                return NSRange(location: location + rangeOfLineFeed.location, length: rangeOfLineFeed.length)
            } else {
                return nil
            }
        }
    }
}
