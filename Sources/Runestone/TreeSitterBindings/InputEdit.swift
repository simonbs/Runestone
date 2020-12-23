//
//  InputEdit.swift
//  
//
//  Created by Simon Støvring on 17/12/2020.
//

import TreeSitter

final class InputEdit {
    let startByte: uint
    let oldEndByte: uint
    let newEndByte: uint
    let startPoint: SourcePoint
    let oldEndPoint: SourcePoint
    let newEndPoint: SourcePoint

    init(
        startByte: uint,
        oldEndByte: uint,
        newEndByte: uint,
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
            start_byte: startByte,
            old_end_byte: oldEndByte,
            new_end_byte: newEndByte,
            start_point: startPoint.rawValue,
            old_end_point: oldEndPoint.rawValue,
            new_end_point: newEndPoint.rawValue)
    }
}
