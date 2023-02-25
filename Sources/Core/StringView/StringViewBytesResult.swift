import Byte

public final class StringViewBytesResult {
    // The bytes are not deallocated by this type.
    public let bytes: UnsafePointer<Int8>
    public let length: ByteCount

    init(bytes: UnsafePointer<Int8>, length: ByteCount) {
        self.bytes = bytes
        self.length = length
    }
}
