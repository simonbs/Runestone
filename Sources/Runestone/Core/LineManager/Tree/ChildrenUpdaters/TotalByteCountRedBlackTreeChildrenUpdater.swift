//import Foundation
//
//struct TotalByteCountRedBlackTreeChildrenUpdater: RedBlackTreeChildrenUpdating {
//    typealias NodeID = LineNodeID
//    typealias NodeValue = Int
//    typealias NodeData = LineNodeData
//
//    func updateChildren(of node: Node) -> Bool {
//        var totalByteCount = node.data.byteCount
//        if let leftNode = node.left {
//            totalByteCount += leftNode.data.totalByteCount
//        }
//        if let rightNode = node.right {
//            totalByteCount += rightNode.data.totalByteCount
//        }
//        if totalByteCount != node.data.totalByteCount {
//            node.data.totalByteCount = totalByteCount
//            return true
//        } else {
//            return false
//        }
//    }
//}
