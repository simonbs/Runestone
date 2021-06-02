//
//  LineFragmentNode.swift
//  
//
//  Created by Simon on 29/05/2021.
//

import CoreGraphics
import Foundation

struct LineFragmentNodeID: RedBlackTreeNodeID {
    let id = UUID()
}

final class LineFragmentNodeData {
    var lineFragment: LineFragment?
    var lineFragmentHeight: CGFloat {
        return lineFragment?.scaledSize.height ?? 0
    }
    var totalLineFragmentHeight: CGFloat = 0

    init(lineFragment: LineFragment?) {
        self.lineFragment = lineFragment
    }
}

typealias LineFragmentNode = RedBlackTreeNode<LineFragmentNodeID, Int, LineFragmentNodeData>

extension LineFragmentNode {
    func updateTotalLineFragmentHeight() {
        data.totalLineFragmentHeight = previous.data.totalLineFragmentHeight + data.lineFragmentHeight
    }
}
