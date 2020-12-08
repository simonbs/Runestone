//
//  NewLineFinder.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

enum NewLineFinder {
    static func rangeOfNextNewLine(in text: NSString, startingAt location: Int) -> NSRange? {
        let rangeOfCarriageReturn = text.range(of: NewLineSymbol.carriageReturn)
        if rangeOfCarriageReturn.location != NSNotFound {
            if rangeOfCarriageReturn.location < text.length - 1 {
                let nextCharacterRange = NSMakeRange(rangeOfCarriageReturn.location + 1, 1)
                if text.substring(with: nextCharacterRange) == NewLineSymbol.lineFeed {
                    let totalLength = rangeOfCarriageReturn.length + nextCharacterRange.length
                    return NSRange(location: rangeOfCarriageReturn.location, length: totalLength)
                } else {
                    return rangeOfCarriageReturn
                }
            } else {
                return rangeOfCarriageReturn
            }
        } else {
            let rangeOfLineFeed = text.range(of: NewLineSymbol.lineFeed)
            if rangeOfLineFeed.location != NSNotFound {
                return rangeOfLineFeed
            } else {
                return nil
            }
        }
    }
}
