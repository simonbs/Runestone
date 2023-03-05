import Foundation

struct TextStoreChange {
    let byteRange: ByteRange
    let bytesAdded: ByteCount
    let oldEndLinePosition: LinePosition
    let startLinePosition: LinePosition
    let newEndLinePosition: LinePosition
    let lineChangeSet: LineChangeSet
}
