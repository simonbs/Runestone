package struct BytesView {
    // The bytes are not deallocated by this type.
    package let bytes: UnsafePointer<Int8>
    package let length: ByteCount

    package init(bytes: UnsafePointer<Int8>, length: ByteCount) {
        self.bytes = bytes
        self.length = length
    }
}
