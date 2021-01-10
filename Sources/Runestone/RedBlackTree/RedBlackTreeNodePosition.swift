//
//  RedBlackTreeNodePosition.swift
//  
//
//  Created by Simon Støvring on 09/12/2020.
//

import Foundation

public final class RedBlackTreeNodePosition {
    public let nodeStartLocation: Int
    public let index: Int
    public let offset: Int
    public let totalLength: Int

    init(nodeStartLocation: Int, index: Int, offset: Int, totalLength: Int) {
        self.nodeStartLocation = nodeStartLocation
        self.index = index
        self.offset = offset
        self.totalLength = totalLength
    }
}
