import Foundation

/// A request owns its tree copies, while requests from one parse generation share
/// a text copy that is never mutated. Keep this object alive while using captures:
/// their nodes refer to the snapshot trees.
final class TreeSitterHighlightSnapshot {
    struct Layer {
        let tree: TreeSitterTree
        let query: TreeSitterQuery
    }

    private let layers: [Layer]
    private let stringView: StringView

    init(layers: [Layer], stringView: StringView) {
        self.layers = layers
        self.stringView = stringView
    }

    func captures(in range: ByteRange, isCancelled: () -> Bool = { false }) -> [TreeSitterCapture] {
        guard !range.isEmpty, !isCancelled() else {
            return []
        }
        var captures: [TreeSitterCapture] = []
        for layer in layers {
            guard !isCancelled() else {
                return []
            }
            let cursor = TreeSitterQueryCursor(query: layer.query, node: layer.tree.rootNode)
            cursor.setQueryRange(range)
            cursor.execute()
            captures += cursor.validCaptures(in: stringView, isCancelled: isCancelled)
        }
        guard !isCancelled() else {
            return []
        }
        captures.sort(by: TreeSitterCapture.captureLayerSorting)
        return isCancelled() ? [] : captures
    }
}
