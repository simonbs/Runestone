//
//  InputEdit.swift
//  
//
//  Created by Simon Støvring on 17/12/2020.
//

import TreeSitter

final class InputEdit {
    let startByte: ByteCount
    let oldEndByte: ByteCount
    let newEndByte: ByteCount
    let startPoint: SourcePoint
    let oldEndPoint: SourcePoint
    let newEndPoint: SourcePoint

    init(
        startByte: ByteCount,
        oldEndByte: ByteCount,
        newEndByte: ByteCount,
        startPoint: SourcePoint,
        oldEndPoint: SourcePoint,
        newEndPoint: SourcePoint) {
        self.startByte = startByte
        self.oldEndByte = oldEndByte
        self.newEndByte = newEndByte
        self.startPoint = startPoint
        self.oldEndPoint = oldEndPoint
        self.newEndPoint = newEndPoint
    }

    func asRawInputEdit() -> TSInputEdit {
        return TSInputEdit(
            start_byte: UInt32(startByte.value),
            old_end_byte: UInt32(oldEndByte.value),
            new_end_byte: UInt32(newEndByte.value),
            start_point: startPoint.rawValue,
            old_end_point: oldEndPoint.rawValue,
            new_end_point: newEndPoint.rawValue)
    }
}

extension InputEdit: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[InputEdit startByte=\(startByte) oldEndByte=\(oldEndByte) newEndByte=\(newEndByte)"
            + " startPoint=\(startPoint) oldEndPoint=\(oldEndPoint) newEndPoint=\(newEndPoint)]"
    }
}
