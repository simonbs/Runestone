struct TreeSitterByteRead {
    let bytes: UnsafePointer<Int8>
    let length: UInt32

    init(bytes: UnsafePointer<Int8>, length: UInt32) {
        self.bytes = bytes
        self.length = length
    }
}
