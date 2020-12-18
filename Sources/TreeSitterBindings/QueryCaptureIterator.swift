//
//  QueryCaptureIterator.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import TreeSitter

final class QueryCaptureIterator: IteratorProtocol {
    private let cursorPointer: OpaquePointer
    private let query: Query
    private let node: Node
    private var haveExecuted = false

    convenience init(query: Query, node: Node) {
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

    func execute() {
        if !haveExecuted {
            haveExecuted = true
            ts_query_cursor_exec(cursorPointer, query.pointer, node.rawValue)
        }
    }

    func setQueryRange(from start: UInt32, to end: UInt32) {
        ts_query_cursor_set_byte_range(cursorPointer, start, end)
    }

    func setQueryRange(from startPoint: SourcePoint, to endPoint: SourcePoint) {
        ts_query_cursor_set_point_range(cursorPointer, startPoint.rawValue, endPoint.rawValue)
    }

    func next() -> QueryCapture? {
        guard haveExecuted else {
            fatalError("Attempted iterating over captures but the underlying query ahven't been executed.")
        }
        let matchPointer = UnsafeMutablePointer<TSQueryMatch>.allocate(capacity: 1)
        let captureIndex = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        guard ts_query_cursor_next_capture(cursorPointer, matchPointer, captureIndex) else {
            return nil
        }
        let capturePointer = matchPointer.pointee.captures + Int(captureIndex.pointee)
        let index = capturePointer.pointee.index
        let name = query.captureName(forId: index)
        let node = Node(node: capturePointer.pointee.node)
        return QueryCapture(node: node, index: index, name: name)
    }
}
