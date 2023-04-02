import Combine
import Foundation

struct RendererStringProvider {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let line: LineNode
    private let lineFragment: LineFragment

    init(stringView: CurrentValueSubject<StringView, Never>, line: LineNode, lineFragment: LineFragment) {
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
        return stringView.value.substring(in: lineRange)
    }
}
