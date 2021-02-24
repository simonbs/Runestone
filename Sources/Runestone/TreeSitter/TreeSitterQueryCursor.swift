//
//  TreeSitterQueryCursor.swift
//  
//
//  Created by Simon Støvring on 16/02/2021.
//

import TreeSitter

final class TreeSitterQueryCursor {
    private let pointer: OpaquePointer
    private let query: TreeSitterQuery
    private let node: TreeSitterNode
    private var haveExecuted = false

    init(query: TreeSitterQuery, node: TreeSitterNode) {
        self.pointer = ts_query_cursor_new()
        self.query = query
        self.node = node
    }

    deinit {
        ts_query_cursor_delete(pointer)
    }

    func setQueryRange(_ range: ByteRange) {
        let start = UInt32(range.location.value)
        let end = UInt32((range.location + range.length).value)
        ts_query_cursor_set_byte_range(pointer, start, end)
    }

    func execute() {
        if !haveExecuted {
            haveExecuted = true
            ts_query_cursor_exec(pointer, query.pointer, node.rawValue)
        }
    }

    func allMatches() -> [TreeSitterQueryMatch] {
        guard haveExecuted else {
            fatalError("Cannot get captures of a query that has not been executed.")
        }
        let matchPointer = UnsafeMutablePointer<TSQueryMatch>.allocate(capacity: 1)
        let captureIndex = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        var result: [TreeSitterQueryMatch] = []
        while ts_query_cursor_next_capture(pointer, matchPointer, captureIndex) {
            let captureCount = Int(matchPointer.pointee.capture_count)
            let captures: [TreeSitterCapture] = (0 ..< captureCount).map { i in
                let capture = matchPointer.pointee.captures[i]
                let patternIndex = matchPointer.pointee.pattern_index
                let captureName = query.captureName(forId: capture.index)
                let node = TreeSitterNode(node: capture.node)
                let predicates = query.predicates(forPatternIndex: UInt32(patternIndex))
                return TreeSitterCapture(node: node, index: capture.index, name: captureName, predicates: predicates)
            }
            let match = TreeSitterQueryMatch(captures: captures)
            result.append(match)
        }
        return result
    }
}
