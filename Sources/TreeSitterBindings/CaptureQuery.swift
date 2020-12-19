//
//  CaptureQuery.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import TreeSitter

public final class CaptureQuery {
    private let cursorPointer: OpaquePointer
    private let query: Query
    private let node: Node
    private var haveExecuted = false

    public convenience init(query: Query, node: Node) {
        self.init(cursorPointer: ts_query_cursor_new(), query: query, node: node)
    }

    fileprivate init(cursorPointer: OpaquePointer, query: Query, node: Node) {
        self.cursorPointer = cursorPointer
        self.query = query
        self.node = node
    }

    deinit {
        ts_query_cursor_delete(cursorPointer)
    }

    public func setQueryRange(from start: UInt32, to end: UInt32) {
        ts_query_cursor_set_byte_range(cursorPointer, start, end)
    }

    public func setQueryRange(from startPoint: SourcePoint, to endPoint: SourcePoint) {
        ts_query_cursor_set_point_range(cursorPointer, startPoint.rawValue, endPoint.rawValue)
    }

    public func execute() {
        if !haveExecuted {
            haveExecuted = true
            ts_query_cursor_exec(cursorPointer, query.pointer, node.rawValue)
        }
    }

    public func allCaptures() -> [Capture] {
        guard haveExecuted else {
            fatalError("Cannot get captures of a query that has not been executed.")
        }
        let matchPointer = UnsafeMutablePointer<TSQueryMatch>.allocate(capacity: 1)
        let captureIndex = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        var result: [Node: Capture] = [:]
        while ts_query_cursor_next_capture(cursorPointer, matchPointer, captureIndex) {
            for i in 0 ..< matchPointer.pointee.capture_count {
                let match = matchPointer.pointee.captures[Int(i)]
                let captureName = query.captureName(forId: match.index)
                let node = Node(node: match.node)
                result[node] = Capture(startByte: node.startByte, endByte: node.endByte, name: captureName)
            }
        }
        return Array(result.values)
    }
}
