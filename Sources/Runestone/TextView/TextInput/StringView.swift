//
//  StringView.swift
//  
//
//  Created by Simon Støvring on 05/03/2021.
//

import Foundation

struct StringViewBytesResult {
    let bytes: UnsafePointer<Int8>
    let length: ByteCount
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
        if location >= 0 && location < string.length, let scalar = Unicode.Scalar(internalString.character(at: location)) {
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
        guard range.lowerBound.value >= 0 && range.upperBound <= string.byteCount else {
            return nil
        }
        let encoding = String.Encoding.utf16LittleEndian.rawValue
        let maxByteCount = range.length.value
        var usedLength: Int = 0
        let stringRange = NSRange(range)
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxByteCount)
        let didGetBytes = string.getBytes(
            buffer,
            maxLength: maxByteCount,
            usedLength: &usedLength,
            encoding: encoding,
            options: [],
            range: stringRange,
            remaining: nil)
        if didGetBytes {
            return StringViewBytesResult(bytes: buffer, length: ByteCount(usedLength))
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
