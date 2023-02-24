import Foundation

public extension String {
    var byteCount: ByteCount {
        ByteCount(utf16.count * 2)
    }
}
