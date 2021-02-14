//
//  String+ByteCount.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import Foundation

public extension String {
    var byteCount: ByteCount {
        return ByteCount(utf8.count)
    }

    func byteOffset(at location: Int) -> ByteCount {
        let utf8View = utf8
        let utf16View = utf16
        let utf16index = utf16View.index(utf16View.startIndex, offsetBy: location, limitedBy: utf16View.endIndex)!
        let utf8index = utf16index.samePosition(in: utf8View)!
        let distance = utf8View.distance(from: utf8View.startIndex, to: utf8index)
        return ByteCount(distance)
    }

    func byteRange(from range: NSRange) -> ByteRange {
        let utf8View = utf8
        let utf16View = utf16
        let startUTF16Index = utf16View.index(utf16View.startIndex, offsetBy: range.location, limitedBy: utf16View.endIndex)!
        let startUTF8Index = startUTF16Index.samePosition(in: utf8View)!
        let endUTF16Index = utf16View.index(startUTF16Index, offsetBy: range.length, limitedBy: utf16View.endIndex)!
        let endUTF8Index = endUTF16Index.samePosition(in: utf8View)!
        let location = utf8View.distance(from: utf8View.startIndex, to: startUTF8Index)
        let length = utf8View.distance(from: startUTF8Index, to: endUTF8Index)
        return ByteRange(location: ByteCount(location), length: ByteCount(length))
    }

    func location(from byteOffset: ByteCount) -> Int {
        let utf8View = utf8
        let utf16View = utf16
        let location = byteOffset.value
        let utf8Index = utf8View.index(utf8View.startIndex, offsetBy: location, limitedBy: utf8View.endIndex) ?? utf8View.endIndex
        return utf16View.distance(from: utf16View.startIndex, to: utf8Index)
    }

    func range(from byteRange: ByteRange) -> NSRange {
        let utf8View = utf8
        let utf16View = utf16
        let startUTF8Index = utf8View.index(utf8View.startIndex, offsetBy: byteRange.location.value, limitedBy: utf8View.endIndex) ?? utf8View.endIndex
        let endUTF8Index = utf8View.index(startUTF8Index, offsetBy: byteRange.length.value, limitedBy: utf8View.endIndex) ?? utf8View.endIndex
        let startUTF16Index = startUTF8Index.samePosition(in: utf16View)!
        let endUTF16Index = endUTF8Index.samePosition(in: utf16View)!
        let location = utf16View.distance(from: utf16View.startIndex, to: startUTF16Index)
        let length = utf16View.distance(from: startUTF16Index, to: endUTF16Index)
        return NSRange(location: location, length: length)
    }
}
