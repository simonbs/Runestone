//
//  File.swift
//  
//
//  Created by Simon Støvring on 09/01/2021.
//

import Foundation

final class DocumentLineNodeContext {
    var delimiterLength: Int
    var length: Int {
        return totalLength - delimiterLength
    }
    var totalLength: Int {
        return node!.value
    }

    weak var node: RedBlackTreeNode<DocumentLineNodeContext>?

    init() {
        self.delimiterLength = 0
    }
}

extension DocumentLineNodeContext: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[DocumentLine lineNumber=\(node!.index) location=\(node!.location) length=\(length)]"
    }
}
