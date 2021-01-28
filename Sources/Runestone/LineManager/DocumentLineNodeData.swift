//
//  DocumentLineNodeData.swift
//  
//
//  Created by Simon Støvring on 09/01/2021.
//

import Foundation
import CoreGraphics

final class DocumentLineNodeData {
    var delimiterLength = 0 {
        didSet {
            assert(delimiterLength >= 0 && delimiterLength <= 2)
        }
    }
    var totalLength: Int = 0
    var length: Int {
        return totalLength - delimiterLength
    }
    var frameHeight: CGFloat
    var totalFrameHeight: CGFloat = 0
    var nodeTotalByteCount = ByteCount(0)
    var startByte: ByteCount {
        return node!.tree.startByte(of: node!)
    }
    var byteCount = ByteCount(0)
    var byteRange: ByteRange {
        return ByteRange(location: startByte, length: byteCount - ByteCount(delimiterLength))
    }
    var totalByteRange: ByteRange {
        return ByteRange(location: startByte, length: byteCount)
    }

    weak var node: DocumentLineNode?

    init(frameHeight: CGFloat) {
        self.frameHeight = frameHeight
    }
}

private extension DocumentLineTree {
    func startByte(of node: Node) -> ByteCount {
        return offset(of: node, valueKeyPath: \.data.byteCount, totalValueKeyPath: \.data.nodeTotalByteCount, minimumValue: ByteCount(0))
    }
}
