//
//  File.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter

@objc public final class SourcePoint: NSObject {
    public var row: CUnsignedInt {
        return rawValue.row
    }
    public var column: CUnsignedInt {
        return rawValue.row
    }

    let rawValue: TSPoint

    init(point: TSPoint) {
        self.rawValue = point
        super.init()
    }

    @objc public init(row: CUnsignedInt, column: CUnsignedInt) {
        self.rawValue = TSPoint(row: row, column: column)
        super.init()
    }
}

extension SourcePoint {
    public override var debugDescription: String {
        return "(row = \(row), column = \(column)"
    }
}
