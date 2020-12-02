//
//  File.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import Foundation

extension String {
    func convert(_ range: NSRange) -> Range<String.Index> {
        return index(startIndex, offsetBy: range.location) ..< index(startIndex, offsetBy: range.location + range.length)
    }

    func convert(_ range: Range<String.Index>) -> NSRange {
        let startLocation = distance(from: startIndex, to: range.lowerBound)
        let endLocation = distance(from: startIndex, to: range.upperBound)
        return NSMakeRange(startLocation, endLocation - startLocation)
    }
}
