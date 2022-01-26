import TreeSitter

final class TreeSitterQueryMatch {
    let captures: [TreeSitterCapture]

    init(captures: [TreeSitterCapture]) {
        self.captures = captures
    }

    func capture(forIndex index: UInt32) -> TreeSitterCapture? {
        return captures.first { $0.index == index }
    }
}
