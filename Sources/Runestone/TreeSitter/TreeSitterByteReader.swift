import Combine

final class TreeSitterByteReader {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let targetByteCount: ByteCount

    init(stringView: CurrentValueSubject<StringView, Never>, targetByteCount: ByteCount = 4 * 1_024) {
        self.stringView = stringView
        self.targetByteCount = targetByteCount
    }

    func readBytes(startingAt byteIndex: ByteCount) -> TreeSitterByteRead? {
        guard byteIndex.value >= 0 && byteIndex < stringView.value.string.byteCount else {
            return nil
        }
        let endByte = min(byteIndex + targetByteCount, stringView.value.string.byteCount)
        let byteRange = ByteRange(from: byteIndex, to: endByte)
        if let result = stringView.value.bytes(in: byteRange) {
            return TreeSitterByteRead(bytes: result.bytes, length: UInt32(result.length.value))
        } else {
            return nil
        }
    }
}
