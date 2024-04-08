import Foundation
import TreeSitter

protocol TreeSitterLanguageModeDelegate: AnyObject {
    func treeSitterLanguageMode(_ languageMode: TreeSitterInternalLanguageMode, bytesAt byteIndex: ByteCount) -> TreeSitterTextProviderResult?
}

final class TreeSitterInternalLanguageMode: InternalLanguageMode {
    weak var delegate: TreeSitterLanguageModeDelegate?
    var canHighlight: Bool {
        rootLanguageLayer.canHighlight
    }

    private let stringView: StringView
    private let parser: TreeSitterParser
    private let lineManager: LineManager
    private let rootLanguageLayer: TreeSitterLanguageLayer
    private let operationQueue = OperationQueue()
    private let parseLock = NSLock()

    init(language: TreeSitterInternalLanguage, languageProvider: TreeSitterLanguageProvider?, stringView: StringView, lineManager: LineManager) {
        self.stringView = stringView
        self.lineManager = lineManager
        operationQueue.name = "TreeSitterLanguageMode"
        operationQueue.qualityOfService = .default
        parser = TreeSitterParser(encoding: TSInputEncodingUTF16)
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
        parseLock.withLock {
            rootLanguageLayer.parse(text)
        }
    }

    func parse(_ text: NSString, completion: @escaping ((Bool) -> Void)) {
        operationQueue.cancelAllOperations()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            if let self = self, let operation = operation, !operation.isCancelled {
                self.parse(text)
                DispatchQueue.main.async {
                    completion(!operation.isCancelled)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
        operationQueue.addOperation(operation)
    }

    func textDidChange(_ change: TextChange) -> LineChangeSet {
        let bytesRemoved = change.byteRange.length
        let bytesAdded = change.bytesAdded
        let edit = TreeSitterInputEdit(
            startByte: change.byteRange.location,
            oldEndByte: change.byteRange.location + bytesRemoved,
            newEndByte: change.byteRange.location + bytesAdded,
            startPoint: TreeSitterTextPoint(change.startLinePosition),
            oldEndPoint: TreeSitterTextPoint(change.oldEndLinePosition),
            newEndPoint: TreeSitterTextPoint(change.newEndLinePosition))
        return rootLanguageLayer.apply(edit)
    }

    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        rootLanguageLayer.captures(in: range)
    }

    func createLineSyntaxHighlighter() -> LineSyntaxHighlighter {
        TreeSitterSyntaxHighlighter(stringView: stringView, languageMode: self, operationQueue: operationQueue)
    }

    func currentIndentLevel(of line: DocumentLineNode, using indentStrategy: IndentStrategy) -> Int {
        let measurer = IndentLevelMeasurer(stringView: stringView)
        return measurer.indentLevel(lineStartLocation: line.location, lineTotalLength: line.data.totalLength, tabLength: indentStrategy.tabLength)
    }

    func strategyForInsertingLineBreak(from startLinePosition: LinePosition,
                                       to endLinePosition: LinePosition,
                                       using indentStrategy: IndentStrategy) -> InsertLineBreakIndentStrategy {
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
        if let node = rootLanguageLayer.layerAndNode(at: linePosition)?.node, let type = node.type {
            let startLocation = TextLocation(LinePosition(node.startPoint))
            let endLocation = TextLocation(LinePosition(node.endPoint))
            return SyntaxNode(type: type, startLocation: startLocation, endLocation: endLocation)
        } else {
            return nil
        }
    }

    func detectIndentStrategy() -> DetectedIndentStrategy {
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
