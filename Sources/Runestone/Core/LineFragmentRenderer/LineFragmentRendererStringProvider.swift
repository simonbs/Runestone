import Combine
import Foundation

struct LineFragmentRendererStringProvider<LineFragmentType: LineFragment> {
    private let stringView: any StringView
    private let line: LineNode
    private let lineFragment: LineFragmentType

    init(stringView: some StringView, line: LineNode, lineFragment: LineFragmentType) {
        self.stringView = stringView
        self.line = line
        self.lineFragment = lineFragment
    }

    var string: String? {
        let lineFragmentRange = lineFragment.visibleRange
        let lineRange = NSRange(
            location: line.location + lineFragmentRange.location,
            length: lineFragmentRange.length
        )
        return stringView.substring(in: lineRange)
    }
}
