import Combine
import Foundation
import TreeSitter

final class TreeSitterInternalLanguageMode: InternalLanguageMode {
    var canHighlight: Bool {
        rootLanguageLayer.canHighlight
    }

    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let parser = TreeSitterParser()
    private let rootLanguageLayer: TreeSitterLanguageLayer
    private let operationQueue = OperationQueue()

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        language: TreeSitterInternalLanguage,
        languageProvider: TreeSitterLanguageProvider?,
        parser: TreeSitterParser = TreeSitterParser(),
        tree: TreeSitterTree? = nil
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        operationQueue.name = "TreeSitterLanguageMode"
        operationQueue.qualityOfService = .userInitiated
        rootLanguageLayer = TreeSitterLanguageLayer(
            stringView: stringView,
            lineManager: lineManager,
            language: language,
            languageProvider: languageProvider,
            parser: parser,
            tree: tree
        )
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

    func textDidChange(_ edit: TextEdit) -> LineChangeSet {
        let bytesRemoved = edit.byteRange.length
        let bytesAdded = edit.bytesAdded
        let edit = TreeSitterInputEdit(
            startByte: edit.byteRange.location,
            oldEndByte: edit.byteRange.location + bytesRemoved,
            newEndByte: edit.byteRange.location + bytesAdded,
            startPoint: TreeSitterTextPoint(edit.startLinePosition),
            oldEndPoint: TreeSitterTextPoint(edit.oldEndLinePosition),
            newEndPoint: TreeSitterTextPoint(edit.newEndLinePosition)
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
        let indentService = TreeSitterIndentService(
            indentationScopes: indentationScopes,
            stringView: stringView.value,
            lineManager: lineManager.value,
            indentLengthInSpaces: indentStrategy.lengthInSpaces
        )
        let startNode = startLayerAndNode?.node
        let endNode = endLayerAndNode?.node
        return indentService.strategyForInsertingLineBreak(
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
            string: stringView.value.string,
            lineManager: lineManager.value,
            tree: tree
        )
        return detector.detect()
    }
}
