import Combine
import Foundation
import TreeSitterLib

final class TreeSitterInternalLanguageMode: InternalLanguageMode {
    let stringView: CurrentValueSubject<StringView, Never>
    let lineManager: CurrentValueSubject<LineManager, Never>
    var canHighlight: Bool {
        rootLanguageLayer.canHighlight
    }

    private let parser = TreeSitterParser()
    private let rootLanguageLayer: TreeSitterLanguageLayer
    private let operationQueue = OperationQueue()

    init(
        language: TreeSitterInternalLanguage,
        languageProvider: TreeSitterLanguageProvider?,
        stringView: StringView,
        lineManager: LineManager
    ) {
        self.stringView = CurrentValueSubject(stringView)
        self.lineManager = CurrentValueSubject(lineManager)
        operationQueue.name = "TreeSitterLanguageMode"
        operationQueue.qualityOfService = .userInitiated
        rootLanguageLayer = TreeSitterLanguageLayer(
            language: language,
            languageProvider: languageProvider,
            parser: parser,
            stringView: stringView,
            lineManager: lineManager
        )
        parser.delegate = self
    }

    deinit {
        operationQueue.cancelAllOperations()
    }

    func parse(_ text: NSString) {
        rootLanguageLayer.parse(text)
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

    func textDidChange(_ change: TextStoreChange) -> LineChangeSet {
        let bytesRemoved = change.byteRange.length
        let bytesAdded = change.bytesAdded
        let edit = TreeSitterInputEdit(
            startByte: change.byteRange.location,
            oldEndByte: change.byteRange.location + bytesRemoved,
            newEndByte: change.byteRange.location + bytesAdded,
            startPoint: TreeSitterTextPoint(change.startLinePosition),
            oldEndPoint: TreeSitterTextPoint(change.oldEndLinePosition),
            newEndPoint: TreeSitterTextPoint(change.newEndLinePosition)
        )
        return rootLanguageLayer.apply(edit)
    }

    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        rootLanguageLayer.captures(in: range)
    }

    func createSyntaxHighlighter(with theme: CurrentValueSubject<Theme, Never>) -> SyntaxHighlighter {
        TreeSitterSyntaxHighlighter(
            stringView: stringView,
            languageMode: self,
            theme: theme,
            operationQueue: operationQueue
        )
    }

    func currentIndentLevel(of line: LineNode, using indentStrategy: IndentStrategy) -> Int {
        let measurer = IndentLevelMeasurer(stringView: stringView.value)
        return measurer.indentLevel(
            lineStartLocation: line.location,
            lineTotalLength: line.data.totalLength,
            tabLength: indentStrategy.tabLength
        )
    }

    func strategyForInsertingLineBreak(
        from startLinePosition: LinePosition,
        to endLinePosition: LinePosition,
        using indentStrategy: IndentStrategy
    ) -> InsertLineBreakIndentStrategy {
        let startLayerAndNode = rootLanguageLayer.layerAndNode(at: startLinePosition)
        let endLayerAndNode = rootLanguageLayer.layerAndNode(at: endLinePosition)
        guard let indentationScopes = startLayerAndNode?.layer.language.indentationScopes ?? endLayerAndNode?.layer.language.indentationScopes else {
            return InsertLineBreakIndentStrategy(indentLevel: 0, insertExtraLineBreak: false)
        }
        let indentController = TreeSitterIndentController(
            indentationScopes: indentationScopes,
            stringView: stringView.value,
            lineManager: lineManager.value,
            tabLength: indentStrategy.tabLength
        )
        let startNode = startLayerAndNode?.node
        let endNode = endLayerAndNode?.node
        return indentController.strategyForInsertingLineBreak(
            between: startNode,
            and: endNode,
            caretStartPosition: startLinePosition,
            caretEndPosition: endLinePosition
        )
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
        guard let tree = rootLanguageLayer.tree else {
            return .unknown
        }
        let detector = TreeSitterIndentStrategyDetector(
            stringView: stringView.value,
            lineManager: lineManager.value,
            tree: tree
        )
        return detector.detect()
    }
}

extension TreeSitterInternalLanguageMode: TreeSitterParserDelegate {
    func parser(_ parser: TreeSitterParser, bytesAt byteIndex: ByteCount) -> TreeSitterTextProviderResult? {
        guard byteIndex.value >= 0 && byteIndex < stringView.value.string.byteCount else {
            return nil
        }
        let targetByteCount: ByteCount = 4 * 1_024
        let endByte = min(byteIndex + targetByteCount, stringView.value.string.byteCount)
        let byteRange = ByteRange(from: byteIndex, to: endByte)
        if let result = stringView.value.bytes(in: byteRange) {
            return TreeSitterTextProviderResult(bytes: result.bytes, length: UInt32(result.length.value))
        } else {
            return nil
        }
    }
}
