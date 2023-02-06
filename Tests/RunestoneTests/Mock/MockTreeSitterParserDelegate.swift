import Foundation
@testable import Runestone

final class MockTreeSitterParserDelegate: TreeSitterParserDelegate {
    var string: NSString {
        get {
            stringView.string
        }
        set {
            stringView.string = newValue
        }
    }

    private let stringView = StringView()

    func parser(_ parser: TreeSitterParser, bytesAt byteIndex: ByteCount) -> TreeSitterTextProviderResult? {
        let maxLength = stringView.string.byteCount - byteIndex
        let length = min(2_048, maxLength)
        let byteRange = ByteRange(location: byteIndex, length: length)
        if let result = stringView.bytes(in: byteRange) {
            return TreeSitterTextProviderResult(bytes: result.bytes, length: UInt32(result.length.value))
        } else {
            return nil
        }
    }
}
