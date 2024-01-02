import _RunestoneStringUtilities
import Foundation

struct TextEdit<LineType: Line> {
    let byteRange: ByteRange
    let bytesAdded: ByteCount
    let oldEndLinePosition: LinePosition
    let startLinePosition: LinePosition
    let newEndLinePosition: LinePosition
    let lineChangeSet: LineChangeSet<LineType>

    init(
        byteRange: ByteRange,
        bytesAdded: ByteCount,
        oldEndLinePosition: LinePosition,
        startLinePosition: LinePosition,
        newEndLinePosition: LinePosition,
        lineChangeSet: LineChangeSet<LineType>
    ) {
        self.byteRange = byteRange
        self.bytesAdded = bytesAdded
        self.oldEndLinePosition = oldEndLinePosition
        self.startLinePosition = startLinePosition
        self.newEndLinePosition = newEndLinePosition
        self.lineChangeSet = lineChangeSet
    }

    init(
        replacing range: NSRange,
        with newString: String,
        lineManagerEdit: LineManagerEdit<LineType>
    ) {
        self.init(
            byteRange: ByteRange(utf16Range: range),
            bytesAdded: newString.byteCount,
            oldEndLinePosition: lineManagerEdit.oldEndLinePosition,
            startLinePosition: lineManagerEdit.startLinePosition,
            newEndLinePosition: lineManagerEdit.newEndLinePosition,
            lineChangeSet: lineManagerEdit.lineChangeSet
        )
    }
}
