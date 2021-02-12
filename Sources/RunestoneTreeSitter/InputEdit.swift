//
//  InputEdit.swift
//  
//
//  Created by Simon Støvring on 17/12/2020.
//

import TreeSitter
import RunestoneUtils

public final class InputEdit {
    public let startByte: ByteCount
    public let oldEndByte: ByteCount
    public let newEndByte: ByteCount
    public let startPoint: TextPoint
    public let oldEndPoint: TextPoint
    public let newEndPoint: TextPoint

    public init(
        startByte: ByteCount,
        oldEndByte: ByteCount,
        newEndByte: ByteCount,
        startPoint: TextPoint,
        oldEndPoint: TextPoint,
        newEndPoint: TextPoint) {
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
    public var debugDescription: String {
        return "[InputEdit startByte=\(startByte) oldEndByte=\(oldEndByte) newEndByte=\(newEndByte)"
            + " startPoint=\(startPoint) oldEndPoint=\(oldEndPoint) newEndPoint=\(newEndPoint)]"
    }
}
