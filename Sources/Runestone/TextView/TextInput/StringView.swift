//
//  StringView.swift
//  
//
//  Created by Simon Støvring on 05/03/2021.
//

import Foundation

struct StringViewBytesResult {
    let bytes: UnsafePointer<Int8>
    let length: Int
}

final class StringView {
    var string: NSString {
        get {
            return internalString
        }
        set {
            internalString = NSMutableString(string: newValue)
        }
    }
    private var internalString: NSMutableString {
        didSet {
            if internalString != oldValue {
                invalidate()
            }
        }
    }
    private var swiftString: String {
        if let swiftString = _swiftString {
            return swiftString
        } else {
            let swiftString = internalString as String
            _swiftString = swiftString
            return swiftString
        }
    }

    private var _swiftString: String?

    init(string: NSMutableString = NSMutableString()) {
        self.internalString = string
    }

    convenience init(string: String) {
        self.init(string: NSMutableString(string: string))
    }
    
    func substring(in range: NSRange) -> String? {
        if range.upperBound <= internalString.length {
            return internalString.substring(with: range)
        } else {
            return nil
        }
    }

    func character(at location: Int) -> Character? {
        if let scalar = Unicode.Scalar(internalString.character(at: location)) {
            return Character(scalar)
        } else {
            return nil
        }
    }

    func replaceCharacters(in range: NSRange, with string: String) {
        internalString.replaceCharacters(in: range, with: string)
        invalidate()
    }

    func bytes(in range: ByteRange) -> StringViewBytesResult? {
        guard range.lowerBound.value >= 0 && range.upperBound.value <= string.length * 2 else {
            return nil
        }
        if let cString = string.cString(using: String.Encoding.utf16LittleEndian.rawValue) {
            let offsetCString = cString.advanced(by: range.location.value)
            return StringViewBytesResult(bytes: offsetCString, length: range.length.value)
        } else {
            return nil
        }
    }
}

private extension StringView {
    private func invalidate() {
        _swiftString = nil
    }
}
