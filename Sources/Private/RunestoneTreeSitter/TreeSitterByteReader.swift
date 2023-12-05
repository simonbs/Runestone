import _RunestoneStringUtilities

package final class TreeSitterByteReader<TreeSitterStringViewType: TreeSitterStringView> {
    private let stringView: TreeSitterStringViewType
    private let targetByteCount: ByteCount

    package init(stringView: TreeSitterStringViewType, targetByteCount: ByteCount = 4 * 1_024) {
        self.stringView = stringView
        self.targetByteCount = targetByteCount
    }

    package func readBytes(startingAt byteIndex: ByteCount) -> TreeSitterByteRead? {
        guard byteIndex.value >= 0 && byteIndex < stringView.byteCount else {
            return nil
        }
        let endByte = min(byteIndex + targetByteCount, stringView.byteCount)
        let byteRange = ByteRange(from: byteIndex, to: endByte)
        if let result = stringView.bytes(in: byteRange) {
            return TreeSitterByteRead(bytes: result.bytes, length: UInt32(result.length.value))
        } else {
            return nil
        }
    }
}
