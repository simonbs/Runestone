//
//  StringView.swift
//  
//
//  Created by Simon Støvring on 05/03/2021.
//

import Foundation

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
    private var data: Data? {
        if let data = _data {
            return data
        } else {
            let data = internalString.data(using: String.Encoding.utf8.rawValue)
            _data = data
            return data
        }
    }

    private var _swiftString: String?
    private var _data: Data?

    init(string: NSMutableString = NSMutableString()) {
        self.internalString = string
    }

    convenience init(string: String) {
        self.init(string: NSMutableString(string: string))
    }

    func byteOffset(at location: Int) -> ByteCount {
        return swiftString.byteOffset(at: location)
    }

    func substring(in byteRange: ByteRange) -> String? {
        if let subdata = data?[byteRange.lowerBound.value ..< byteRange.upperBound.value] {
            return String(data: subdata, encoding: .utf8)
        } else {
            return nil
        }
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
}

private extension StringView {
    private func invalidate() {
        _swiftString = nil
        _data = nil
    }
}
