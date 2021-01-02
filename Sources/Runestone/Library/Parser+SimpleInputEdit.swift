//
//  File.swift
//  
//
//  Created by Simon Støvring on 01/01/2021.
//

import Foundation

struct SimpleInputEdit {
    let location: Int
    let bytesRemoved: Int
    let bytesAdded: Int
    let startLinePosition: LinePosition
    let oldEndLinePosition: LinePosition
    let newEndLinePosition: LinePosition
}

extension Parser {
    @discardableResult
    func apply(_ inputEdit: SimpleInputEdit) -> Bool {
        let inputEdit = InputEdit(
            startByte: UInt32(inputEdit.location),
            oldEndByte: UInt32(inputEdit.location + inputEdit.bytesRemoved),
            newEndByte: UInt32(inputEdit.location + inputEdit.bytesAdded),
            startPoint: SourcePoint(inputEdit.startLinePosition),
            oldEndPoint: SourcePoint(inputEdit.oldEndLinePosition),
            newEndPoint: SourcePoint(inputEdit.newEndLinePosition))
        return apply(inputEdit)
    }
}

private extension SourcePoint {
    convenience init(_ linePosition: LinePosition) {
        self.init(row: UInt32(linePosition.lineNumber), column: UInt32(linePosition.column))
    }
}
