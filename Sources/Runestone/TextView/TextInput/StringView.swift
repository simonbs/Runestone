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
    
    func substring(in range: NSRange) -> String {
        return internalString.substring(with: range)
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

    func bytes(at byteIndex: ByteCount) -> StringViewBytesResult? {
        let location = byteIndex.value / 2
        return bytes(at: location)
    }

    func bytes(at location: Int) -> StringViewBytesResult? {
        guard location < string.length else {
            return nil
        }
        let range = string.rangeOfComposedCharacterSequence(at: location)
        let byteCount = range.length * 2
        let mutableBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: byteCount)
        let encoding: String.Encoding = .utf16
        var bufferLength = 0
        let success = string.getBytes(
            mutableBuffer,
            maxLength: byteCount,
            usedLength: &bufferLength,
            encoding: encoding.rawValue,
            options: [],
            range: range,
            remaining: nil)
        if success {
            let buffer = UnsafePointer(mutableBuffer)
            mutableBuffer.deallocate()
            return StringViewBytesResult(bytes: buffer, length: bufferLength)
        } else {
            mutableBuffer.deallocate()
            return nil
        }
    }
}

private extension StringView {
    private func invalidate() {
        _swiftString = nil
    }
}
