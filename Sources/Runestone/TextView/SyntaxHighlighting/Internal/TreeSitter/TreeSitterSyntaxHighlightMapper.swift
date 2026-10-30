import Foundation

struct TreeSitterSyntaxCapture: Equatable {
    let byteRange: ByteRange
    let name: String
}

extension TreeSitterSyntaxCapture {
    init(_ capture: TreeSitterCapture) {
        self.init(byteRange: capture.byteRange, name: capture.name)
    }
}

enum TreeSitterSyntaxHighlightMapper {
    static func highlights(for captures: [TreeSitterSyntaxCapture], localTo localRange: ByteRange) -> [SyntaxHighlight] {
        captures.compactMap { capture in
            guard capture.byteRange.overlaps(localRange) else {
                return nil
            }
            // Captures may extend beyond a rendered line, for example an
            // unterminated string. Keep the semantic result local to the request.
            let start = max(capture.byteRange.lowerBound, localRange.lowerBound)
            let end = min(capture.byteRange.upperBound, localRange.upperBound)
            let localByteRange = ByteRange(location: start - localRange.lowerBound, length: end - start)
            guard !localByteRange.isEmpty else {
                return nil
            }
            return SyntaxHighlight(range: NSRange(localByteRange), name: capture.name)
        }
    }
}
