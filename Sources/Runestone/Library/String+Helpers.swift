//
//  String+Helpers.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import Foundation

extension String {
    var byteCount: ByteCount {
        return ByteCount(utf16.count * 2)
    }
}
