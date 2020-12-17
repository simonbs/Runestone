//
//  File.swift
//  
//
//  Created by Simon Støvring on 17/12/2020.
//

import Foundation
import TreeSitter

@objc public final class InputEdit: NSObject {
    public let startByte: uint
    public let oldEndByte: uint
    public let newEndByte: uint
    public let startPoint: SourcePoint
    public let oldEndPoint: SourcePoint
    public let newEndPoint: SourcePoint

    @objc public init(
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
