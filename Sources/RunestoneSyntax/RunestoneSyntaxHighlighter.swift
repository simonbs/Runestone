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
    public let injectionsQuery: String?
    public let foldsQuery: String?

    public init(language: OpaquePointer, highlightsQuery: String? = nil,
                injectionsQuery: String? = nil, foldsQuery: String? = nil) {
        self.language = language
        self.highlightsQuery = highlightsQuery
        self.injectionsQuery = injectionsQuery
        self.foldsQuery = foldsQuery
    }
}

/// Resolves a language named by a Tree-sitter injection query.
///
/// Hosts should normalize aliases such as `js` and `javascript`. Returning nil
/// leaves that injected range styled by its containing language.
public typealias RunestoneSyntaxLanguageProvider = @Sendable (String) -> RunestoneSyntaxLanguage?

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
    case invalidInjectionsQuery(offset: UInt32)
    case invalidFoldsQuery(offset: UInt32)
    case parseFailed
    case cancelled
}

/// The platform-neutral parsing surface consumed by editor presentations.
///
/// Implementations must copy update input before returning and may invoke
/// completions on any queue. A new update or `cancel()` invalidates all older
/// update, capture, and fold requests.
public protocol RunestoneSyntaxHighlighting: AnyObject, Sendable {
    func update(_ text: String, completion: (@Sendable (Result<Void, RunestoneSyntaxError>) -> Void)?)
    func captures(in range: NSRange,
                  completion: @escaping @Sendable (Result<[RunestoneSyntaxCapture], RunestoneSyntaxError>) -> Void)
    func folds(completion: @escaping @Sendable (Result<[RunestoneSyntaxFold], RunestoneSyntaxError>) -> Void)
    func cancel()
}

public extension RunestoneSyntaxHighlighting {
    func update(_ text: String) { update(text, completion: nil) }
}

/// Incremental, serial Tree-sitter parsing with cancellable semantic snapshots.
///
/// Updates copy their input before leaving the caller. Superseded generations
/// never publish captures or folds. Query work checks cancellation between
/// matches, bounding obsolete work even though Tree-sitter's parse call itself
/// is synchronous in the pinned C runtime.
public final class RunestoneSyntaxHighlighter: RunestoneSyntaxHighlighting, @unchecked Sendable {
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
    private let injectionsQuery: Query?
    private let languageProvider: RunestoneSyntaxLanguageProvider?

    public init(language: RunestoneSyntaxLanguage,
                languageProvider: RunestoneSyntaxLanguageProvider? = nil) throws {
        self.language = language
        self.languageProvider = languageProvider
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
        if let source = language.injectionsQuery {
            injectionsQuery = try Query(source: source, language: language.language,
                                        error: RunestoneSyntaxError.invalidInjectionsQuery)
        } else {
            injectionsQuery = nil
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
            var result = self.highlightsQuery?.captures(in: range, state: state) {
                operation.isCancelled || !self.isCurrent(requestedGeneration)
            } ?? []
            result += self.injectedCaptures(
                in: state.children, intersecting: range, parentOffset: 0, query: \.highlightsQuery,
                cancelled: { operation.isCancelled || !self.isCurrent(requestedGeneration) })
            guard !operation.isCancelled, self.isCurrent(requestedGeneration) else {
                completion(.failure(.cancelled))
                return
            }
            completion(.success(result.sorted {
                $0.range.location == $1.range.location ? $0.range.length > $1.range.length : $0.range.location < $1.range.location
            }))
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
            let wholeDocument = NSRange(location: 0, length: state.text.length)
            var captures = self.foldsQuery?.foldCaptures(state: state) {
                operation.isCancelled || !self.isCurrent(requestedGeneration)
            } ?? []
            captures += self.injectedCaptures(
                in: state.children, intersecting: wholeDocument, parentOffset: 0, query: \.foldsQuery,
                cancelled: { operation.isCancelled || !self.isCurrent(requestedGeneration) })
            guard !operation.isCancelled, self.isCurrent(requestedGeneration) else {
                completion(.failure(.cancelled))
                return
            }
            completion(.success(captures.map { RunestoneSyntaxFold(range: $0.range) }))
        }
        queue.addOperation(operation)
    }

    public func cancel() {
        let request = stateLock.withLock { () -> UpdateRequest? in
            generation &+= 1
            defer { updateRequest = nil }
            return updateRequest
        }
        queue.cancelAllOperations()
        request?.complete(.failure(.cancelled))
    }
}

private extension RunestoneSyntaxHighlighter {
    func injectedCaptures(in children: [ChildState], intersecting documentRange: NSRange,
                          parentOffset: Int, query: KeyPath<ChildState, Query?>,
                          cancelled: () -> Bool) -> [RunestoneSyntaxCapture] {
        var captures: [RunestoneSyntaxCapture] = []
        for child in children where !cancelled() {
            let absoluteOffset = parentOffset + child.offset
            let childDocumentRange = NSRange(location: absoluteOffset, length: child.state.text.length)
            let intersection = NSIntersectionRange(documentRange, childDocumentRange)
            guard intersection.length > 0 else { continue }
            if let childQuery = child[keyPath: query] {
                let local = NSRange(location: intersection.location - absoluteOffset, length: intersection.length)
                let localCaptures = query == \ChildState.foldsQuery
                    ? childQuery.foldCaptures(state: child.state, isCancelled: cancelled)
                    : childQuery.captures(in: local, state: child.state, isCancelled: cancelled)
                captures += localCaptures.map {
                    RunestoneSyntaxCapture(
                        range: NSRange(location: $0.range.location + absoluteOffset, length: $0.range.length),
                        name: $0.name)
                }
            }
            captures += injectedCaptures(
                in: child.state.children, intersecting: documentRange, parentOffset: absoluteOffset,
                query: query, cancelled: cancelled)
        }
        return captures
    }

    final class Tree: @unchecked Sendable {
        let pointer: OpaquePointer
        init(_ pointer: OpaquePointer) { self.pointer = pointer }
        deinit { ts_tree_delete(pointer) }
    }

    struct State: @unchecked Sendable {
        let text: NSString
        let tree: Tree
        let children: [ChildState]
    }

    struct ChildState: @unchecked Sendable {
        let offset: Int
        let state: State
        let highlightsQuery: Query?
        let foldsQuery: Query?
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
        // Query compilation is expensive, especially for Markdown's inline
        // injection on every paragraph. Share immutable runtimes throughout
        // this parse, including nested injections, then release the lookup.
        // A fresh cache on each update allows providers to change definitions.
        var runtimes: [String: ChildRuntime] = [:]
        var unavailableLanguages: Set<String> = []
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
        let base = State(text: text, tree: Tree(parsed), children: [])
        let children = injectedChildren(in: base, depth: 0, runtimes: &runtimes, unavailable: &unavailableLanguages)
        return State(text: text, tree: base.tree, children: children)
    }

    func injectedChildren(in parent: State, depth: Int, runtimes: inout [String: ChildRuntime],
                          unavailable: inout Set<String>) -> [ChildState] {
        guard depth < 4, let injectionsQuery else { return [] }
        return injectionsQuery.injections(in: parent).compactMap { injection in
            let childText = parent.text.substring(with: injection.range) as NSString
            guard injection.range.length > 0,
                  let runtime = childRuntime(named: injection.language, runtimes: &runtimes, unavailable: &unavailable),
                  let childState = parseChild(childText, runtime: runtime, depth: depth + 1,
                                              runtimes: &runtimes, unavailable: &unavailable) else { return nil }
            return ChildState(offset: injection.range.location, state: childState,
                              highlightsQuery: runtime.highlights, foldsQuery: runtime.folds)
        }
    }

    struct ChildRuntime {
        let language: RunestoneSyntaxLanguage
        let highlights: Query?
        let injections: Query?
        let folds: Query?
    }

    func childRuntime(named name: String, runtimes: inout [String: ChildRuntime],
                      unavailable: inout Set<String>) -> ChildRuntime? {
        if let runtime = runtimes[name] { return runtime }
        guard !unavailable.contains(name) else { return nil }
        guard let language = languageProvider?(name), let runtime = try? childRuntime(language) else {
            unavailable.insert(name)
            return nil
        }
        runtimes[name] = runtime
        return runtime
    }

    func childRuntime(_ language: RunestoneSyntaxLanguage) throws -> ChildRuntime {
        let highlights = try language.highlightsQuery.map {
            try Query(source: $0, language: language.language, error: RunestoneSyntaxError.invalidHighlightsQuery)
        }
        let injections = try language.injectionsQuery.map {
            try Query(source: $0, language: language.language, error: RunestoneSyntaxError.invalidInjectionsQuery)
        }
        let folds = try language.foldsQuery.map {
            try Query(source: $0, language: language.language, error: RunestoneSyntaxError.invalidFoldsQuery)
        }
        return ChildRuntime(language: language, highlights: highlights, injections: injections, folds: folds)
    }

    func parseChild(_ text: NSString, runtime: ChildRuntime, depth: Int,
                    runtimes: inout [String: ChildRuntime], unavailable: inout Set<String>) -> State? {
        guard let parser = ts_parser_new() else { return nil }
        defer { ts_parser_delete(parser) }
        guard ts_parser_set_language(parser, runtime.language.language),
              let data = (text as String).data(using: .utf16LittleEndian) else { return nil }
        let parsed = data.withUnsafeBytes { bytes in
            ts_parser_parse_string_encoding(parser, nil, bytes.bindMemory(to: Int8.self).baseAddress,
                                            UInt32(bytes.count), TSInputEncodingUTF16LE)
        }
        guard let parsed else { return nil }
        let base = State(text: text, tree: Tree(parsed), children: [])
        guard depth < 4, let query = runtime.injections else { return base }
        let children = query.injections(in: base).compactMap { injection -> ChildState? in
            let childText = text.substring(with: injection.range) as NSString
            guard let nestedRuntime = childRuntime(named: injection.language, runtimes: &runtimes, unavailable: &unavailable),
                  let state = parseChild(childText, runtime: nestedRuntime, depth: depth + 1,
                                         runtimes: &runtimes, unavailable: &unavailable) else { return nil }
            return ChildState(offset: injection.range.location, state: state,
                              highlightsQuery: nestedRuntime.highlights, foldsQuery: nestedRuntime.folds)
        }
        return State(text: text, tree: base.tree, children: children)
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

    struct Injection {
        let range: NSRange
        let language: String
    }

    func injections(in state: RunestoneSyntaxHighlighter.State) -> [Injection] {
        let cursor = ts_query_cursor_new()
        defer { ts_query_cursor_delete(cursor) }
        ts_query_cursor_exec(cursor, pointer, ts_tree_root_node(state.tree.pointer))
        var rawMatch = TSQueryMatch(id: 0, pattern_index: 0, capture_count: 0, captures: nil)
        var result: [Injection] = []
        while ts_query_cursor_next_match(cursor, &rawMatch) {
            let captures = UnsafeBufferPointer(start: rawMatch.captures, count: Int(rawMatch.capture_count))
            guard predicatesPass(pattern: UInt32(rawMatch.pattern_index), captures: captures, text: state.text) else { continue }
            let properties = setProperties(pattern: UInt32(rawMatch.pattern_index))
            let capturedLanguage = captures.first { capture in
                let name = captureName(capture.index)
                return name == "injection.language" || name == "language"
            }.flatMap { captureText($0.index, captures: captures, text: state.text) }
            let explicitLanguage = capturedLanguage ?? properties["injection.language"]
            for capture in captures {
                let name = captureName(capture.index)
                // HTML and other bundled queries can name the language directly on the content capture.
                guard !name.hasPrefix("_"), name != "injection.language", name != "language" else { continue }
                let languageName = explicitLanguage ?? (name == "injection.content" ? "" : name)
                let language = languageName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !language.isEmpty else { continue }
                let start = Int(ts_node_start_byte(capture.node)) / 2
                let end = Int(ts_node_end_byte(capture.node)) / 2
                guard start >= 0, end > start, end <= state.text.length else { continue }
                result.append(Injection(range: NSRange(location: start, length: end - start), language: language))
            }
        }
        return result
    }

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

    /// Folding captures have range directives and heading section semantics that
    /// must not be interpreted as highlighting predicates or single-line ranges.
    func foldCaptures(state: RunestoneSyntaxHighlighter.State,
                      isCancelled: () -> Bool) -> [RunestoneSyntaxCapture] {
        guard let cursor = ts_query_cursor_new() else { return [] }
        defer { ts_query_cursor_delete(cursor) }
        let root = ts_tree_root_node(state.tree.pointer)
        ts_query_cursor_exec(cursor, pointer, root)
        let lines = FoldingText(string: state.text, isCancelled: isCancelled)
        var match = TSQueryMatch(id: 0, pattern_index: 0, capture_count: 0, captures: nil)
        var result: [RunestoneSyntaxCapture] = []
        var headings: [(node: TSNode, level: Int, container: TSNode)] = []
        while !isCancelled(), ts_query_cursor_next_match(cursor, &match) {
            let captures = UnsafeBufferPointer(start: match.captures, count: Int(match.capture_count))
            guard predicatesPass(pattern: UInt32(match.pattern_index), captures: captures,
                                 text: state.text, folding: true) else { continue }
            let groups = Dictionary(grouping: captures.filter { captureName($0.index) == "fold" }, by: \.index)
            for (id, group) in groups {
                guard let start = group.map({ Int(ts_node_start_byte($0.node)) / 2 }).min(),
                      let end = group.map({ Int(ts_node_end_byte($0.node)) / 2 }).max() else { continue }
                if let range = foldExtent(start..<end, capture: id, pattern: UInt32(match.pattern_index), lines: lines) {
                    result.append(.init(range: NSRange(location: range.lowerBound, length: range.count), name: "fold"))
                }
            }
            for capture in captures where captureName(capture.index) == "fold.heading" {
                let node = capture.node
                var level: Int?
                for index in 0..<ts_node_child_count(node) {
                    let child = ts_node_child(node, index)
                    let type = String(cString: ts_node_type(child))
                    for value in 1...6 where type == "atx_h\(value)_marker" || type == "setext_h\(value)_underline" {
                        level = value
                    }
                }
                guard let level else { continue }
                var container = ts_node_parent(node)
                while !ts_node_is_null(container),
                      !["document", "block_quote", "list_item"].contains(String(cString: ts_node_type(container))) {
                    container = ts_node_parent(container)
                }
                headings.append((node, level, ts_node_is_null(container) ? root : container))
            }
        }
        // A heading ends before the next heading of equal or higher rank in
        // its container. Nested quotes/lists never terminate an outer section.
        var stack: [(node: TSNode, level: Int, container: TSNode)] = []
        func append(_ heading: (node: TSNode, level: Int, container: TSNode), end: Int) {
            let start = Int(ts_node_start_byte(heading.node)) / 2
            let containerEnd = Int(ts_node_end_byte(heading.container)) / 2
            let finish = min(end, containerEnd)
            guard finish > start else { return }
            result.append(.init(range: NSRange(location: start, length: finish - start), name: "fold"))
        }
        for heading in headings.sorted(by: { ts_node_start_byte($0.node) < ts_node_start_byte($1.node) }) {
            while let previous = stack.last, ts_node_eq(previous.container, heading.container), previous.level >= heading.level {
                append(stack.removeLast(), end: Int(ts_node_start_byte(heading.node)) / 2)
            }
            // Close headings from a nested container once it has ended.
            while let previous = stack.last, ts_node_end_byte(previous.container) <= ts_node_start_byte(heading.node) {
                append(stack.removeLast(), end: Int(ts_node_end_byte(previous.container)) / 2)
            }
            // A nested container may have been above a sibling section on the stack.
            while let previous = stack.last, ts_node_eq(previous.container, heading.container), previous.level >= heading.level {
                append(stack.removeLast(), end: Int(ts_node_start_byte(heading.node)) / 2)
            }
            stack.append(heading)
        }
        for heading in stack { append(heading, end: Int(ts_node_end_byte(heading.container)) / 2) }
        return isCancelled() ? [] : result.sorted { $0.range.location < $1.range.location }
    }

    private func foldExtent(_ range: Range<Int>, capture: UInt32, pattern: UInt32,
                            lines: FoldingText) -> Range<Int>? {
        var count: UInt32 = 0
        guard let raw = ts_query_predicates_for_pattern(pointer, pattern, &count) else { return range }
        var extent: Range<Int>? = range
        var index = 0
        while index < Int(count) {
            let name = queryString(raw[index].value_id)
            index += 1
            var steps: [TSQueryPredicateStep] = []
            while index < Int(count), raw[index].type != TSQueryPredicateStepTypeDone {
                steps.append(raw[index]); index += 1
            }
            index += 1
            guard ["trim!", "offset!"].contains(name), let first = steps.first,
                  first.type == TSQueryPredicateStepTypeCapture, first.value_id == capture,
                  let current = extent else { continue }
            let values = steps.dropFirst().compactMap { step -> Int? in
                guard step.type == TSQueryPredicateStepTypeString else { return nil }
                return Int(queryString(step.value_id))
            }
            if name == "offset!" {
                extent = steps.count == 5 && values.count == 4 ? lines.offset(current, values: values) : nil
            } else {
                let flags = steps.count == 1 ? [0, 0, 1, 0] : values
                extent = (steps.count == 1 || steps.count == 5) && flags.count == 4 && flags.allSatisfy { $0 == 0 || $0 == 1 }
                    ? lines.trim(current, flags: flags) : nil
            }
        }
        return extent
    }

    private func captureName(_ id: UInt32) -> String {
        var length: UInt32 = 0
        guard let name = ts_query_capture_name_for_id(pointer, id, &length) else { return "" }
        return String(decoding: UnsafeBufferPointer(start: UnsafeRawPointer(name).assumingMemoryBound(to: UInt8.self),
                                                     count: Int(length)), as: UTF8.self)
    }

    private enum Step { case capture(UInt32), string(String) }

    private func setProperties(pattern: UInt32) -> [String: String] {
        var count: UInt32 = 0
        guard let raw = ts_query_predicates_for_pattern(pointer, pattern, &count), count > 0 else { return [:] }
        var result: [String: String] = [:]
        var index = 0
        while index < Int(count) {
            let name = queryString(raw[index].value_id)
            index += 1
            var strings: [String] = []
            while index < Int(count), raw[index].type != TSQueryPredicateStepTypeDone {
                if raw[index].type == TSQueryPredicateStepTypeString {
                    strings.append(queryString(raw[index].value_id))
                }
                index += 1
            }
            index += 1
            if name == "set!", strings.count >= 2 { result[strings[0]] = strings[1] }
        }
        return result
    }

    private func predicatesPass(pattern: UInt32, captures: UnsafeBufferPointer<TSQueryCapture>, text: NSString, folding: Bool = false) -> Bool {
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
            if folding, ["trim!", "offset!"].contains(name) { continue }
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

// Immutable UTF-16 line coordinates for folding range directives.
private final class FoldingText {
    let string: NSString
    private var starts = [0]

    init(string: NSString, isCancelled: () -> Bool) {
        self.string = string
        for index in 0..<string.length {
            if index % 4_096 == 0, isCancelled() {
                return
            }
            if string.character(at: index) == 10 { starts.append(index + 1) }
        }
    }

    func row(at offset: Int) -> Int {
        var lower = 0
        var upper = starts.count
        while lower + 1 < upper {
            let middle = (lower + upper) / 2
            if starts[middle] <= offset { lower = middle } else { upper = middle }
        }
        return lower
    }

    private func end(of row: Int) -> Int { row + 1 < starts.count ? starts[row + 1] : string.length }

    private func contentEnd(of row: Int) -> Int {
        row + 1 < starts.count ? starts[row + 1] - 1 : string.length
    }

    func offset(_ range: Range<Int>, values: [Int]) -> Range<Int>? {
        let startRow = row(at: range.lowerBound)
        let endRow = row(at: range.upperBound)
        let newStartRow = startRow + values[0]
        let newEndRow = endRow + values[2]
        guard starts.indices.contains(newStartRow), starts.indices.contains(newEndRow) else {
            return nil
        }
        // Columns use the editor's UTF-16 coordinates; row offsets preserve the
        // existing column just as Tree-sitter query offset directives do.
        let startColumn = range.lowerBound - starts[startRow] + values[1]
        let endColumn = range.upperBound - starts[endRow] + values[3]
        guard startColumn >= 0, endColumn >= 0 else {
            return nil
        }
        let start = starts[newStartRow] + startColumn
        let finish = starts[newEndRow] + endColumn
        guard start <= end(of: newStartRow), finish <= end(of: newEndRow), start < finish else {
            return nil
        }
        return start..<finish
    }

    func trim(_ range: Range<Int>, flags: [Int]) -> Range<Int>? {
        guard range.lowerBound >= 0, range.upperBound <= string.length else {
            return nil
        }
        var start = range.lowerBound
        var finish = range.upperBound
        if flags[2] == 1 {
            finish = trimmingEndLines(range)
        }
        if flags[3] == 1 {
            let lineStart = starts[row(at: finish)]
            while finish > max(start, lineStart) && isHorizontalWhitespace(at: finish - 1) { finish -= 1 }
        }
        if flags[0] == 1 {
            while start < finish {
                let startRow = row(at: start)
                let lineEnd = min(contentEnd(of: startRow), finish)
                guard isBlank(start..<max(start, lineEnd)) else { break }
                start = min(end(of: startRow), finish)
            }
        }
        if flags[1] == 1 {
            let lineEnd = contentEnd(of: row(at: start))
            while start < min(finish, lineEnd) && isHorizontalWhitespace(at: start) { start += 1 }
        }
        return start < finish ? start..<finish : nil
    }

    private func trimmingEndLines(_ range: Range<Int>) -> Int {
        let start = range.lowerBound
        var finish = range.upperBound
        var endRow = row(at: finish)
        while start < finish {
            let previous = max(starts[endRow], start)
            let lineEnd = min(contentEnd(of: endRow), finish)
            guard isBlank(previous..<max(previous, lineEnd)) else { break }
            endRow -= 1
            finish = endRow >= row(at: start) ? max(start, contentEnd(of: endRow)) : start
        }
        return finish
    }

    private func isBlank(_ range: Range<Int>) -> Bool {
        string.substring(with: NSRange(location: range.lowerBound, length: range.count))
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isHorizontalWhitespace(at index: Int) -> Bool {
        guard let scalar = UnicodeScalar(string.character(at: index)) else {
            return false
        }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}
