import Foundation

/// Bytes allocated for a text snapshot; the caller must deallocate `bytes`.
public final class StringViewBytesResult {
    // The bytes are not deallocated by this type.
    /// Allocated UTF-16 bytes; deallocate this pointer when finished.
    public let bytes: UnsafePointer<Int8>
    /// The number of initialized bytes.
    public let length: ByteCount

    init(bytes: UnsafePointer<Int8>, length: ByteCount) {
        self.bytes = bytes
        self.length = length
    }
}

/// Mutable UTF-16 text storage used by the editor’s line and parsing models.
public final class StringView {
    /// Current text. Setting this value makes a mutable copy.
    public var string: NSString {
        get {
            internalString
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

    /// Uses the supplied mutable string as the backing storage.
    public init(string: NSMutableString = NSMutableString()) {
        self.internalString = string
    }

    /// Creates storage from a Swift string.
    public convenience init(string: String) {
        self.init(string: NSMutableString(string: string))
    }

    /// Returns a nonempty substring in UTF-16 coordinates, or nil for an invalid range.
    public func substring(in range: NSRange) -> String? {
        if range.location >= 0 && range.upperBound <= internalString.length && range.length > 0 {
            return internalString.substring(with: range)
        } else {
            return nil
        }
    }

    /// Returns a single UTF-16 scalar as a character, or nil if it cannot be represented.
    public func character(at location: Int) -> Character? {
        if location >= 0 && location < string.length, let scalar = Unicode.Scalar(internalString.character(at: location)) {
            return Character(scalar)
        } else {
            return nil
        }
    }

    /// Replaces a valid UTF-16 range and invalidates cached text.
    public func replaceText(in range: NSRange, with string: String) {
        internalString.replaceCharacters(in: range, with: string)
        invalidate()
    }

    /// Allocates a native-endian UTF-16 byte snapshot for a valid range.
    /// The caller must deallocate the returned pointer.
    public func bytes(in range: ByteRange) -> StringViewBytesResult? {
        guard range.lowerBound.value >= 0 && range.upperBound <= string.byteCount else {
            return nil
        }
        let stringRange = NSRange(range)
        var usedLength = 0
        if let buffer = string.getBytes(in: stringRange, encoding: String.preferredUTF16Encoding, usedLength: &usedLength) {
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

// These helpers retain the existing editor byte representation and allocation contract.
private extension NSString {
    var byteCount: ByteCount { ByteCount(length * 2) }

    func getBytes(in range: NSRange, encoding: String.Encoding, usedLength: inout Int) -> UnsafePointer<Int8>? {
        let byteRange = ByteRange(utf16Range: range)
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: byteRange.length.value)
        let success = getBytes(buffer, maxLength: byteRange.length.value, usedLength: &usedLength,
                               encoding: encoding.rawValue, options: [], range: range, remaining: nil)
        return success ? UnsafePointer<Int8>(buffer) : nil
    }
}

private extension NSRange {
    init(_ bytes: ByteRange) {
        self.init(location: bytes.location.value / 2, length: bytes.length.value / 2)
    }
}

private extension String {
    static var preferredUTF16Encoding: String.Encoding {
        let dataA = "abc".data(using: .utf16LittleEndian)
        let dataB = "abc".data(using: .utf16)?.suffix(from: 2)
        return dataA == dataB ? .utf16LittleEndian : .utf16BigEndian
    }
}
