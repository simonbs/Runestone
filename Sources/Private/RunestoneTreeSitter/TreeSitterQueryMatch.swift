import TreeSitter

package final class TreeSitterQueryMatch {
    package let captures: [TreeSitterCapture]

    package init(captures: [TreeSitterCapture]) {
        self.captures = captures
    }

    package func capture(forIndex index: UInt32) -> TreeSitterCapture? {
        captures.first { $0.index == index }
    }
}

extension TreeSitterQueryMatch: CustomDebugStringConvertible {
    package var debugDescription: String {
        "[TreeSitterQueryMatch captures=\(captures.count)]"
    }
}
