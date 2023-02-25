import Foundation

public extension NSRange {
    /// Creates an NSRange from a `ByteRange`.
    /// - Parameter byteRange: `ByteRange` to convert to NSRange.
    init(_ byteRange: ByteRange) {
        let location = byteRange.location.value / 2
        let length = byteRange.length.value / 2
        self.init(location: location, length: length)
    }
}
