import Foundation
import RunestoneEngine
import TreeSitter

/// A raw Tree-sitter language and its semantic queries.
///
/// The pointer must remain valid for the lifetime of this value. Generated
/// Tree-sitter language modules expose process-lifetime pointers.
public struct RunestoneSyntaxLanguage: @unchecked Sendable {
    public let language: OpaquePointer
    public let highlightsQuery: String?
    public let foldsQuery: String?

    public init(language: OpaquePointer, highlightsQuery: String? = nil, foldsQuery: String? = nil) {
        self.language = language
        self.highlightsQuery = highlightsQuery
        self.foldsQuery = foldsQuery
    }
}

/// One semantic capture in absolute UTF-16 document coordinates.
public struct RunestoneSyntaxCapture: Equatable, Sendable {
    public let range: NSRange
    public let name: String

    public init(range: NSRange, name: String) {
        self.range = range
        self.name = name
    }
}

/// One foldable source range in absolute UTF-16 document coordinates.
public struct RunestoneSyntaxFold: Equatable, Sendable {
    public let range: NSRange

    public init(range: NSRange) {
        self.range = range
    }
}

public enum RunestoneSyntaxError: Error, Equatable {
    case invalidLanguage
    case invalidHighlightsQuery(offset: UInt32)
    case invalidFoldsQuery(offset: UInt32)
    case parseFailed
    case cancelled
}

/// Incremental, serial Tree-sitter parsing with cancellable semantic snapshots.
///
/// Updates copy their input before leaving the caller. Superseded generations
/// never publish captures or folds. Query work checks cancellation between
/// matches, bounding obsolete work even though Tree-sitter's parse call itself
/// is synchronous in the pinned C runtime.
public final class RunestoneSyntaxHighlighter: @unchecked Sendable {
    public typealias Completion = @Sendable (Result<[RunestoneSyntaxCapture], RunestoneSyntaxError>) -> Void
    public typealias FoldCompletion = @Sendable (Result<[RunestoneSyntaxFold], RunestoneSyntaxError>) -> Void

    private let queue: OperationQueue
    private let stateLock = NSLock()
    private var generation: UInt64 = 0
    private var state: State?
    private var updateRequest: UpdateRequest?
    private let language: RunestoneSyntaxLanguage
    private let highlightsQuery: Query?
    private let foldsQuery: Query?

    public init(language: RunestoneSyntaxLanguage) throws {
        self.language = language
        let abi = ts_language_abi_version(language.language)
        guard abi >= TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION,
              abi <= TREE_SITTER_LANGUAGE_VERSION else {
            throw RunestoneSyntaxError.invalidLanguage
        }
        if let source = language.highlightsQuery {
            highlightsQuery = try Query(source: source, language: language.language, error: RunestoneSyntaxError.invalidHighlightsQuery)
        } else {
            highlightsQuery = nil
        }
        if let source = language.foldsQuery {
            foldsQuery = try Query(source: source, language: language.language, error: RunestoneSyntaxError.invalidFoldsQuery)
        } else {
            foldsQuery = nil
        }
        queue = OperationQueue()
        queue.name = "RunestoneSyntaxHighlighter"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
    }

    deinit { queue.cancelAllOperations() }

    /// Replaces the source snapshot. The previous syntax tree is edited and
    /// reused when possible; publication is atomic per generation.
    public func update(_ text: String, completion: (@Sendable (Result<Void, RunestoneSyntaxError>) -> Void)? = nil) {
        let stableText = NSString(string: text)
        let request = UpdateRequest(completion)
        let requestedGeneration = beginUpdate(request)
        queue.cancelAllOperations()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self, let operation, !operation.isCancelled,
                  self.isCurrent(requestedGeneration) else {
                request.complete(.failure(.cancelled))
                return
            }
            let previous = self.readState()
            let parsed = self.parse(stableText, reusing: previous)
            guard !operation.isCancelled, self.isCurrent(requestedGeneration) else {
                request.complete(.failure(.cancelled))
                return
            }
            guard let parsed else {
                request.complete(.failure(.parseFailed))
                return
            }
            self.publish(parsed, generation: requestedGeneration)
            request.complete(.success(()))
        }
        queue.addOperation(operation)
    }

    /// Returns captures intersecting a UTF-16 document range.
    public func captures(in range: NSRange, completion: @escaping Completion) {
        let requestedGeneration = currentGeneration()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self, let operation, !operation.isCancelled,
                  self.isCurrent(requestedGeneration), let state = self.readState() else {
                completion(.failure(.cancelled))
                return
            }
            guard let query = self.highlightsQuery else {
                completion(.success([]))
                return
            }
            let result = query.captures(in: range, state: state) {
                operation.isCancelled || !self.isCurrent(requestedGeneration)
            }
            guard !operation.isCancelled, self.isCurrent(requestedGeneration) else {
                completion(.failure(.cancelled))
                return
            }
            completion(.success(result))
        }
        queue.addOperation(operation)
    }

    public func folds(completion: @escaping FoldCompletion) {
        let requestedGeneration = currentGeneration()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self, let operation, !operation.isCancelled,
                  self.isCurrent(requestedGeneration), let state = self.readState() else {
                completion(.failure(.cancelled))
                return
            }
            guard let query = self.foldsQuery else {
                completion(.success([]))
                return
            }
            let wholeDocument = NSRange(location: 0, length: state.text.length)
            let captures = query.captures(in: wholeDocument, state: state) {
                operation.isCancelled || !self.isCurrent(requestedGeneration)
            }
            guard !operation.isCancelled, self.isCurrent(requestedGeneration) else {
                completion(.failure(.cancelled))
                return
            }
            completion(.success(captures.map { RunestoneSyntaxFold(range: $0.range) }))
        }
        queue.addOperation(operation)
    }

    public func cancel() {
        _ = nextGeneration()
        queue.cancelAllOperations()
    }
}

private extension RunestoneSyntaxHighlighter {
    final class Tree: @unchecked Sendable {
        let pointer: OpaquePointer
        init(_ pointer: OpaquePointer) { self.pointer = pointer }
        deinit { ts_tree_delete(pointer) }
    }

    struct State: @unchecked Sendable {
        let text: NSString
        let tree: Tree
    }

    final class UpdateRequest: @unchecked Sendable {
        private let lock = NSLock()
        private var completion: (@Sendable (Result<Void, RunestoneSyntaxError>) -> Void)?

        init(_ completion: (@Sendable (Result<Void, RunestoneSyntaxError>) -> Void)?) {
            self.completion = completion
        }

        func complete(_ result: Result<Void, RunestoneSyntaxError>) {
            let callback = lock.withLock { () -> (@Sendable (Result<Void, RunestoneSyntaxError>) -> Void)? in
                defer { completion = nil }
                return completion
            }
            callback?(result)
        }
    }

    func nextGeneration() -> UInt64 {
        stateLock.withLock {
            generation &+= 1
            return generation
        }
    }

    func beginUpdate(_ request: UpdateRequest) -> UInt64 {
        var previous: UpdateRequest?
        let value = stateLock.withLock { () -> UInt64 in
            generation &+= 1
            previous = updateRequest
            updateRequest = request
            return generation
        }
        previous?.complete(.failure(.cancelled))
        return value
    }

    func currentGeneration() -> UInt64 { stateLock.withLock { generation } }
    func isCurrent(_ value: UInt64) -> Bool { stateLock.withLock { generation == value } }
    func readState() -> State? { stateLock.withLock { state } }

    func publish(_ value: State, generation valueGeneration: UInt64) {
        stateLock.withLock {
            if generation == valueGeneration {
                state = value
                updateRequest = nil
            }
        }
    }

    func parse(_ text: NSString, reusing previous: State?) -> State? {
        guard let parser = ts_parser_new() else { return nil }
        defer { ts_parser_delete(parser) }
        guard ts_parser_set_language(parser, language.language) else { return nil }
        let oldTree: OpaquePointer?
        if let previous {
            let copied = ts_tree_copy(previous.tree.pointer)
            if let copied {
                let edit = incrementalEdit(from: previous.text, to: text)
                var rawEdit = edit
                ts_tree_edit(copied, &rawEdit)
            }
            oldTree = copied
        } else {
            oldTree = nil
        }
        defer { if let oldTree { ts_tree_delete(oldTree) } }
        guard let data = (text as String).data(using: .utf16LittleEndian) else { return nil }
        let parsed = data.withUnsafeBytes { bytes in
            ts_parser_parse_string_encoding(parser, oldTree, bytes.bindMemory(to: Int8.self).baseAddress,
                                            UInt32(bytes.count), TSInputEncodingUTF16LE)
        }
        guard let parsed else { return nil }
        return State(text: text, tree: Tree(parsed))
    }

    func incrementalEdit(from old: NSString, to new: NSString) -> TSInputEdit {
        let prefix = commonPrefix(old, new)
        let suffix = commonSuffix(old, new, after: prefix)
        let oldEnd = old.length - suffix
        let newEnd = new.length - suffix
        return TSInputEdit(
            start_byte: UInt32(prefix * 2), old_end_byte: UInt32(oldEnd * 2), new_end_byte: UInt32(newEnd * 2),
            start_point: point(in: old, at: prefix), old_end_point: point(in: old, at: oldEnd),
            new_end_point: point(in: new, at: newEnd))
    }

    func commonPrefix(_ lhs: NSString, _ rhs: NSString) -> Int {
        let limit = min(lhs.length, rhs.length)
        var index = 0
        while index < limit, lhs.character(at: index) == rhs.character(at: index) { index += 1 }
        if index > 0, index < lhs.length, index < rhs.length,
           isLowSurrogate(lhs.character(at: index)), isHighSurrogate(lhs.character(at: index - 1)) { index -= 1 }
        return index
    }

    func commonSuffix(_ lhs: NSString, _ rhs: NSString, after prefix: Int) -> Int {
        let limit = min(lhs.length, rhs.length) - prefix
        var count = 0
        while count < limit,
              lhs.character(at: lhs.length - 1 - count) == rhs.character(at: rhs.length - 1 - count) { count += 1 }
        if count > 0, lhs.length - count > prefix, rhs.length - count > prefix,
           isLowSurrogate(lhs.character(at: lhs.length - count)),
           isHighSurrogate(lhs.character(at: lhs.length - count - 1)) { count -= 1 }
        return count
    }

    func point(in string: NSString, at offset: Int) -> TSPoint {
        var row: UInt32 = 0
        var column: UInt32 = 0
        var index = 0
        while index < offset {
            let value = string.character(at: index)
            if value == 10 {
                row &+= 1
                column = 0
            } else {
                column &+= 2
            }
            index += 1
        }
        return TSPoint(row: row, column: column)
    }

    func isHighSurrogate(_ value: unichar) -> Bool { (0xD800...0xDBFF).contains(value) }
    func isLowSurrogate(_ value: unichar) -> Bool { (0xDC00...0xDFFF).contains(value) }
}

private final class Query: @unchecked Sendable {
    typealias ErrorFactory = (UInt32) -> RunestoneSyntaxError
    private let pointer: OpaquePointer

    init(source: String, language: OpaquePointer, error: ErrorFactory) throws {
        var offset: UInt32 = 0
        var type = TSQueryErrorNone
        let query = source.withCString {
            ts_query_new(language, $0, UInt32(source.utf8.count), &offset, &type)
        }
        guard let query, type == TSQueryErrorNone else { throw error(offset) }
        pointer = query
    }

    deinit { ts_query_delete(pointer) }

    func captures(in utf16Range: NSRange, state: RunestoneSyntaxHighlighter.State,
                  isCancelled: () -> Bool) -> [RunestoneSyntaxCapture] {
        guard utf16Range.location >= 0, utf16Range.length >= 0,
              utf16Range.location <= state.text.length,
              utf16Range.length <= state.text.length - utf16Range.location else { return [] }
        let cursor = ts_query_cursor_new()
        defer { ts_query_cursor_delete(cursor) }
        ts_query_cursor_set_byte_range(cursor, UInt32(utf16Range.location * 2), UInt32(NSMaxRange(utf16Range) * 2))
        ts_query_cursor_exec(cursor, pointer, ts_tree_root_node(state.tree.pointer))
        var rawMatch = TSQueryMatch(id: 0, pattern_index: 0, capture_count: 0, captures: nil)
        var result: [RunestoneSyntaxCapture] = []
        while !isCancelled(), ts_query_cursor_next_match(cursor, &rawMatch) {
            let rawCaptures = UnsafeBufferPointer(start: rawMatch.captures, count: Int(rawMatch.capture_count))
            guard predicatesPass(pattern: UInt32(rawMatch.pattern_index), captures: rawCaptures, text: state.text) else { continue }
            for capture in rawCaptures where !isCancelled() {
                let start = Int(ts_node_start_byte(capture.node)) / 2
                let end = Int(ts_node_end_byte(capture.node)) / 2
                let clippedStart = max(start, utf16Range.location)
                let clippedEnd = min(end, NSMaxRange(utf16Range))
                guard clippedEnd > clippedStart else { continue }
                result.append(RunestoneSyntaxCapture(
                    range: NSRange(location: clippedStart, length: clippedEnd - clippedStart),
                    name: captureName(capture.index)))
            }
        }
        return isCancelled() ? [] : result
    }

    private func captureName(_ id: UInt32) -> String {
        var length: UInt32 = 0
        guard let name = ts_query_capture_name_for_id(pointer, id, &length) else { return "" }
        return String(decoding: UnsafeBufferPointer(start: UnsafeRawPointer(name).assumingMemoryBound(to: UInt8.self),
                                                     count: Int(length)), as: UTF8.self)
    }

    private enum Step { case capture(UInt32), string(String) }

    private func predicatesPass(pattern: UInt32, captures: UnsafeBufferPointer<TSQueryCapture>, text: NSString) -> Bool {
        var count: UInt32 = 0
        guard let raw = ts_query_predicates_for_pattern(pointer, pattern, &count), count > 0 else { return true }
        var index = 0
        while index < Int(count) {
            let name = queryString(raw[index].value_id)
            index += 1
            var steps: [Step] = []
            while index < Int(count), raw[index].type != TSQueryPredicateStepTypeDone {
                let step = raw[index]
                if step.type == TSQueryPredicateStepTypeCapture { steps.append(.capture(step.value_id)) }
                else if step.type == TSQueryPredicateStepTypeString { steps.append(.string(queryString(step.value_id))) }
                index += 1
            }
            index += 1
            guard evaluate(name: name, steps: steps, captures: captures, text: text) else { return false }
        }
        return true
    }

    private func evaluate(name: String, steps: [Step], captures: UnsafeBufferPointer<TSQueryCapture>, text: NSString) -> Bool {
        if name == "set!" { return true }
        guard steps.count == 2, case .capture(let lhsID) = steps[0],
              let lhs = captureText(lhsID, captures: captures, text: text) else { return false }
        switch (name, steps[1]) {
        case ("eq?", .string(let rhs)): return lhs == rhs
        case ("not-eq?", .string(let rhs)): return lhs != rhs
        case ("eq?", .capture(let rhsID)):
            return captureText(rhsID, captures: captures, text: text) == lhs
        case ("not-eq?", .capture(let rhsID)):
            return captureText(rhsID, captures: captures, text: text) != lhs
        case ("match?", .string(let pattern)):
            return lhs.range(of: pattern, options: .regularExpression) != nil
        case ("not-match?", .string(let pattern)):
            return lhs.range(of: pattern, options: .regularExpression) == nil
        default: return false
        }
    }

    private func captureText(_ id: UInt32, captures: UnsafeBufferPointer<TSQueryCapture>, text: NSString) -> String? {
        guard let capture = captures.first(where: { $0.index == id }) else { return nil }
        let start = Int(ts_node_start_byte(capture.node)) / 2
        let end = Int(ts_node_end_byte(capture.node)) / 2
        guard start >= 0, end >= start, end <= text.length else { return nil }
        return text.substring(with: NSRange(location: start, length: end - start))
    }

    private func queryString(_ id: UInt32) -> String {
        var length: UInt32 = 0
        guard let value = ts_query_string_value_for_id(pointer, id, &length) else { return "" }
        return String(decoding: UnsafeBufferPointer(start: UnsafeRawPointer(value).assumingMemoryBound(to: UInt8.self),
                                                     count: Int(length)), as: UTF8.self)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
