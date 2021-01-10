//
//  DocumentLineNodeData.swift
//  
//
//  Created by Simon Støvring on 09/01/2021.
//

import Foundation

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
}
