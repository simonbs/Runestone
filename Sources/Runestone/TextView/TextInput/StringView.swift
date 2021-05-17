//
//  StringView.swift
//  
//
//  Created by Simon Støvring on 05/03/2021.
//

import Foundation

final class StringView {
    var string: NSMutableString {
        didSet {
            if string != oldValue {
                _swiftString = nil
            }
        }
    }
    private var swiftString: String {
        if let swiftString = _swiftString {
            return swiftString
        } else {
            let swiftString = string as String
            _swiftString = swiftString
            return swiftString
        }
    }

    private var _swiftString: String?

    init(string: NSMutableString = NSMutableString()) {
        self.string = string
    }

    convenience init(string: String) {
        self.init(string: NSMutableString(string: string))
    }

    func byteOffset(at location: Int) -> ByteCount {
        return swiftString.byteOffset(at: location)
    }

    func substring(in byteRange: ByteRange) -> String {
        return swiftString.substring(with: byteRange)
    }

    func substring(in range: NSRange) -> String {
        return string.substring(with: range)
    }

    func character(at location: Int) -> Character? {
        if let scalar = Unicode.Scalar(string.character(at: location)) {
            return Character(scalar)
        } else {
            return nil
        }
    }
}
