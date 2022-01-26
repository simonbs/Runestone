//
//  NSRange+Helpers.swift
//  
//
//  Created by Simon on 12/08/2021.
//

import Foundation

extension NSRange {
    init(_ byteRange: ByteRange) {
        let location = byteRange.location.value / 2
        let length = byteRange.length.value / 2
        self.init(location: location, length: length)
    }

    init?(globalRange: NSRange, localTo line: DocumentLineNode) {
        let lineLocation = line.location
        let lineLength = line.data.length
        let globalLineRange = NSRange(location: lineLocation, length: lineLength)
        if globalRange.overlaps(globalLineRange) {
            let cappedLocation = max(globalRange.location - lineLocation, 0)
            let cappedLength = min(globalRange.length, lineLength - cappedLocation)
            self = NSRange(location: cappedLocation, length: cappedLength)
        } else {
            return nil
        }
    }

    func overlaps(_ range: NSRange) -> Bool {
        let r1 = location ... location + length
        let r2 = range.location ... range.location + range.length
        return r1.overlaps(r2)
    }

    var nonNegativeLength: NSRange {
        if length < 0 {
            let absoluteLength = abs(length)
            let safeAbsoluteLength = min(absoluteLength, location)
            return NSRange(location: location - safeAbsoluteLength, length: safeAbsoluteLength)
        } else {
            return self
        }
    }
}
