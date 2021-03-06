//
//  StringView.swift
//  
//
//  Created by Simon Støvring on 05/03/2021.
//

import Foundation

final class StringView {
    var string: NSMutableString

    init(string: NSMutableString = NSMutableString()) {
        self.string = string
    }

    convenience init(string: String) {
        self.init(string: NSMutableString(string: string))
    }

    func byteOffset(at location: Int) -> ByteCount {
        return (string as String).byteOffset(at: location)
    }

    func substring(in byteRange: ByteRange) -> String {
        return (string as String).substring(with: byteRange)
    }

    func substring(in range: NSRange) -> String {
        return string.substring(with: range)
    }
}
