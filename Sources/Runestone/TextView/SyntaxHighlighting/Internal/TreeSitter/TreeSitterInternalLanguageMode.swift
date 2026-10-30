import Foundation
import TreeSitter

protocol TreeSitterLanguageModeDelegate: AnyObject {
    func treeSitterLanguageMode(_ languageMode: TreeSitterInternalLanguageMode, bytesAt byteIndex: ByteCount) -> TreeSitterTextProviderResult?
}

final class TreeSitterInternalLanguageMode: InternalLanguageMode {
    weak var delegate: TreeSitterLanguageModeDelegate?
    var canHighlight: Bool {
        // Initial parsing runs asynchronously. Its completion invalidates visible
        // lines, so a layout must not wait here for the entire document to parse.
        guard parseLock.try() else {
            return false
        }
        defer { parseLock.unlock() }
        return rootLanguageLayer.canHighlight
    }

    private let stringView: StringView
    private let parser: TreeSitterParser
    private let lineManager: LineManager
    private let rootLanguageLayer: TreeSitterLanguageLayer
    private let operationQueue = OperationQueue()
    private let parseLock = NSLock()
    private var highlightStringView: StringView?
    private var parseOperation: Operation?
    private var foldingOperation: Operation?

    init(language: TreeSitterInternalLanguage, languageProvider: TreeSitterLanguageProvider?, stringView: StringView, lineManager: LineManager) {
        self.stringView = stringView
        self.lineManager = lineManager
        operationQueue.name = "TreeSitterLanguageMode"
        operationQueue.qualityOfService = .default
        parser = TreeSitterParser(encoding: TSInputEncoding.preferredUTF16)
        rootLanguageLayer = TreeSitterLanguageLayer(
            language: language,
            languageProvider: languageProvider,
            parser: parser,
            stringView: stringView,
            lineManager: lineManager)
        parser.delegate = self
    }

    deinit {
        operationQueue.cancelAllOperations()
    }

    func parse(_ text: NSString) {
        foldingOperation?.cancel()
        parseOperation?.cancel()
        parseOperation = nil
        let stableText = NSString(string: text as String)
        parseLock.withLock {
            parseStableText(stableText)
        }
    }

    private func parseStableText(_ text: NSString) {
        let predicateStringView = StringView(string: text as String)
        rootLanguageLayer.parse(text, predicateStringView: predicateStringView)
        highlightStringView = predicateStringView
    }

    func parse(_ text: NSString, completion: @escaping ((Bool) -> Void)) {
        foldingOperation?.cancel()
        parseOperation?.cancel()
        parseOperation = nil
        // NSString may be backed by the editor's NSMutableString. Copy before
        // leaving the calling thread, including text used by injection predicates.
        let stableText = NSString(string: text as String)
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            guard let self = self, let operation = operation else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            let finished = self.parseLock.withLock { () -> Bool in
                guard !operation.isCancelled else {
                    return false
                }
                self.parseStableText(stableText)
                return !operation.isCancelled
            }
            DispatchQueue.main.async {
                if self.parseOperation === operation { self.parseOperation = nil }
                completion(finished && !operation.isCancelled)
            }
        }
        parseOperation = operation
        operationQueue.addOperation(operation)
    }

    func textDidChange(_ change: TextChange) -> LineChangeSet {
        foldingOperation?.cancel()
        parseOperation?.cancel()
        parseOperation = nil
        parseLock.lock()
        defer { parseLock.unlock() }
        let bytesRemoved = change.byteRange.length
        let bytesAdded = change.bytesAdded
        let edit = TreeSitterInputEdit(
            startByte: change.byteRange.location,
            oldEndByte: change.byteRange.location + bytesRemoved,
            newEndByte: change.byteRange.location + bytesAdded,
            startPoint: TreeSitterTextPoint(change.startLinePosition),
            oldEndPoint: TreeSitterTextPoint(change.oldEndLinePosition),
            newEndPoint: TreeSitterTextPoint(change.newEndLinePosition))
        let changes = rootLanguageLayer.apply(edit)
        highlightStringView = nil
        return changes
    }

    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        parseLock.withLock { rootLanguageLayer.captures(in: range) }
    }

    func foldingRanges() -> [TreeSitterFoldingRange] {
        makeFoldingSnapshot()?.ranges() ?? []
    }

    func foldingRanges(completion: @escaping ([TreeSitterFoldingRange]) -> Void) {
        foldingOperation?.cancel()
        guard let snapshot = makeFoldingSnapshot(waitForParse: false) else {
            // Initial parsing invalidates fold ranges when it completes. Never
            // make a feature toggle wait for that whole-document parse.
            foldingOperation = nil
            DispatchQueue.main.async { completion([]) }
            return
        }
        let operation = BlockOperation()
        var ranges: [TreeSitterFoldingRange] = []
        operation.addExecutionBlock { [weak operation] in
            guard let operation = operation, !operation.isCancelled else {
                return
            }
            ranges = snapshot.ranges { operation.isCancelled }
        }
        // Completion also runs when canceled before the execution block starts.
        operation.completionBlock = { [weak self, weak operation] in
            DispatchQueue.main.async {
                guard let self = self, let operation = operation,
                      self.foldingOperation === operation, !operation.isCancelled else {
                    completion([])
                    return
                }
                self.foldingOperation = nil
                completion(ranges)
            }
        }
        foldingOperation = operation
        operationQueue.addOperation(operation)
    }

    private func makeFoldingSnapshot(waitForParse: Bool = true) -> TreeSitterFoldingSnapshot? {
        if waitForParse {
            parseLock.lock()
        } else if !parseLock.try() {
            return nil
        }
        defer { parseLock.unlock() }
        let stableStringView = highlightStringView ?? StringView(string: stringView.string as String)
        highlightStringView = stableStringView
        return TreeSitterFoldingSnapshot(layers: rootLanguageLayer.foldingSnapshotLayers(), stringView: stableStringView)
    }

    /// Called on the editor thread, before any further text mutation. Tree copies
    /// are per request; predicate text is shared until the next parse or edit.
    func makeHighlightSnapshot() -> TreeSitterHighlightSnapshot {
        parseLock.withLock {
            let stableStringView: StringView
            if let cachedStringView = highlightStringView {
                stableStringView = cachedStringView
            } else {
                stableStringView = StringView(string: stringView.string as String)
                highlightStringView = stableStringView
            }
            return TreeSitterHighlightSnapshot(
                layers: rootLanguageLayer.highlightSnapshotLayers(), stringView: stableStringView)
        }
    }

    func createLineSyntaxHighlighter() -> LineSyntaxHighlighter {
        TreeSitterSyntaxHighlighter(languageMode: self, operationQueue: operationQueue)
    }

    func currentIndentLevel(of line: DocumentLineNode, using indentStrategy: IndentStrategy) -> Int {
        let measurer = IndentLevelMeasurer(stringView: stringView)
        return measurer.indentLevel(lineStartLocation: line.location, lineTotalLength: line.data.totalLength, tabLength: indentStrategy.tabLength)
    }

    func strategyForInsertingLineBreak(from startLinePosition: LinePosition,
                                       to endLinePosition: LinePosition,
                                       using indentStrategy: IndentStrategy) -> InsertLineBreakIndentStrategy {
        parseLock.lock()
        defer { parseLock.unlock() }
        let startLayerAndNode = rootLanguageLayer.layerAndNode(at: startLinePosition)
        let endLayerAndNode = rootLanguageLayer.layerAndNode(at: endLinePosition)
        if let indentationScopes = startLayerAndNode?.layer.language.indentationScopes ?? endLayerAndNode?.layer.language.indentationScopes {
            let indentController = TreeSitterIndentController(
                indentationScopes: indentationScopes,
                stringView: stringView,
                lineManager: lineManager,
                tabLength: indentStrategy.tabLength)
            let startNode = startLayerAndNode?.node
            let endNode = endLayerAndNode?.node
            return indentController.strategyForInsertingLineBreak(
                between: startNode,
                and: endNode,
                caretStartPosition: startLinePosition,
                caretEndPosition: endLinePosition)
        } else {
            return InsertLineBreakIndentStrategy(indentLevel: 0, insertExtraLineBreak: false)
        }
    }

    func syntaxNode(at linePosition: LinePosition) -> SyntaxNode? {
        parseLock.lock()
        defer { parseLock.unlock() }
        if let node = rootLanguageLayer.layerAndNode(at: linePosition)?.node, let type = node.type {
            let startLocation = TextLocation(LinePosition(node.startPoint))
            let endLocation = TextLocation(LinePosition(node.endPoint))
            return SyntaxNode(type: type, startLocation: startLocation, endLocation: endLocation)
        } else {
            return nil
        }
    }

    func detectIndentStrategy() -> DetectedIndentStrategy {
        parseLock.lock()
        defer { parseLock.unlock() }
        if let tree = rootLanguageLayer.tree {
            let detector = TreeSitterIndentStrategyDetector(lineManager: lineManager, tree: tree, stringView: stringView)
            return detector.detect()
        } else {
            return .unknown
        }
    }
}

extension TreeSitterInternalLanguageMode: TreeSitterParserDelegate {
    func parser(_ parser: TreeSitterParser, bytesAt byteIndex: ByteCount) -> TreeSitterTextProviderResult? {
        delegate?.treeSitterLanguageMode(self, bytesAt: byteIndex)
    }
}
