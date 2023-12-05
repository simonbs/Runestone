package struct TreeSitterByteRead {
    package let bytes: UnsafePointer<Int8>
    package let length: UInt32

    package init(bytes: UnsafePointer<Int8>, length: UInt32) {
        self.bytes = bytes
        self.length = length
    }
}
