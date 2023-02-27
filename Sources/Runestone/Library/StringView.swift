import Foundation

final class StringView {
    struct BytesResult {
        // The bytes are not deallocated by this type.
        let bytes: UnsafePointer<Int8>
        let length: ByteCount

        init(bytes: UnsafePointer<Int8>, length: ByteCount) {
            self.bytes = bytes
            self.length = length
        }
    }

    var string: NSString {
        get {
            internalString
        }
        set {
            internalString = NSMutableString(string: newValue)
        }
    }
    
    private var internalString: NSMutableString

    init(string: NSMutableString = NSMutableString()) {
        self.internalString = string
    }

    convenience init(string: String) {
        self.init(string: NSMutableString(string: string))
    }

    func substring(in range: NSRange) -> String? {
        if range.location >= 0 && range.upperBound <= internalString.length && range.length > 0 {
            return internalString.substring(with: range)
        } else {
            return nil
        }
    }

    func replaceText(in range: NSRange, with string: String) {
        internalString.replaceCharacters(in: range, with: string)
    }

    func bytes(in range: ByteRange) -> StringView.BytesResult? {
        guard range.lowerBound.value >= 0 && range.upperBound <= string.byteCount else {
            return nil
        }
        let stringRange = NSRange(range)
        var usedLength = 0
        if let buffer = string.getBytes(in: stringRange, encoding: String.preferredUTF16Encoding, usedLength: &usedLength) {
            return StringView.BytesResult(bytes: buffer, length: ByteCount(usedLength))
        } else {
            return nil
        }
    }
}
