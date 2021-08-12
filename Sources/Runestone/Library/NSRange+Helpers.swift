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
}
