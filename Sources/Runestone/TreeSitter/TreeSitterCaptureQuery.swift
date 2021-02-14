//
//  TreeSitterCaptureQuery.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import TreeSitter

final class TreeSitterCaptureQuery {
    private let cursorPointer: OpaquePointer
    private let query: TreeSitterQuery
    private let node: TreeSitterNode
    private var haveExecuted = false

    convenience init(query: TreeSitterQuery, node: TreeSitterNode) {
        self.init(cursorPointer: ts_query_cursor_new(), query: query, node: node)
    }

    fileprivate init(cursorPointer: OpaquePointer, query: TreeSitterQuery, node: TreeSitterNode) {
        self.cursorPointer = cursorPointer
        self.query = query
        self.node = node
    }

    deinit {
        ts_query_cursor_delete(cursorPointer)
    }

    func setQueryRange(_ range: ByteRange) {
        let start = UInt32(range.location.value)
        let end = UInt32((range.location + range.length).value)
        ts_query_cursor_set_byte_range(cursorPointer, start, end)
    }

    func execute() {
        if !haveExecuted {
            haveExecuted = true
            ts_query_cursor_exec(cursorPointer, query.pointer, node.rawValue)
        }
    }

    func allCaptures() -> [TreeSitterCapture] {
        guard haveExecuted else {
            fatalError("Cannot get captures of a query that has not been executed.")
        }
        let matchPointer = UnsafeMutablePointer<TSQueryMatch>.allocate(capacity: 1)
        let captureIndex = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        var result: [TreeSitterNode: TreeSitterCapture] = [:]
        while ts_query_cursor_next_capture(cursorPointer, matchPointer, captureIndex) {
            for i in 0 ..< matchPointer.pointee.capture_count {
                let match = matchPointer.pointee.captures[Int(i)]
                let captureName = query.captureName(forId: match.index)
                let node = TreeSitterNode(node: match.node)
                let byteRange = ByteRange(from: node.startByte, to: node.endByte)
                result[node] = TreeSitterCapture(byteRange: byteRange, name: captureName)
            }
        }
        return Array(result.values)
    }
}
