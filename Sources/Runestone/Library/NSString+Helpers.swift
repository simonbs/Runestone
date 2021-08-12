//
//  File.swift
//  
//
//  Created by Simon on 12/08/2021.
//

import Foundation

extension NSString {
    var byteCount: ByteCount {
        return ByteCount(length * 2)
    }
}
