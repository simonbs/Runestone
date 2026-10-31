import Foundation
import XCTest
@testable import RunestoneEngine

final class RedBlackTreeTests: XCTestCase {
    private struct NodeID: RedBlackTreeNodeID {
        let id = UUID()
        init() {}
    }

    func testMutationsPreserveOrderLocationsAndNodeIdentity() {
        let tree = RedBlackTree<NodeID, Int, Int>(minimumValue: 0, rootValue: 3, rootData: 0)
        var expected = [tree.root!]

        func assertTree(file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(tree.nodeTotalCount, expected.count, file: file, line: line)
            XCTAssertEqual(tree.nodeTotalValue, expected.reduce(0) { $0 + $1.value }, file: file, line: line)
            let actual = Array(RedBlackTreeIterator(tree: tree))
            XCTAssertEqual(actual.count, expected.count, file: file, line: line)
            var location = 0
            for (index, node) in expected.enumerated() {
                XCTAssertTrue(actual[index] === node, file: file, line: line)
                XCTAssertTrue(tree.node(atIndex: index) === node, file: file, line: line)
                XCTAssertEqual(node.index, index, file: file, line: line)
                XCTAssertEqual(node.location, location, file: file, line: line)
                for offset in 0..<node.value {
                    XCTAssertTrue(tree.node(containingLocation: location + offset) === node, file: file, line: line)
                }
                location += node.value
            }
        }

        for index in 1...20 {
            let position = (index * 7) % expected.count
            let node = tree.insertNode(value: index % 5 + 1, data: index, after: expected[position])
            expected.insert(node, at: position + 1)
            assertTree()
        }
        for index in [10, 2, 13, 4, 0, 7, 3, 5] {
            let removed = expected.remove(at: index)
            tree.remove(removed)
            assertTree()
        }
    }
}
