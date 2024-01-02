import CoreGraphics
import Foundation

final class Typesetter: Typesetting {
    typealias State = LineHeightMultiplierReadable

    private let state: State
    private let stringView: StringView
    private let lineBreakSuggester: LineBreakSuggesting
    private var map: [LineID: LineTypesetter] = [:]

    init(state: State, stringView: StringView, lineBreakSuggester: LineBreakSuggesting) {
        self.state = state
        self.stringView = stringView
        self.lineBreakSuggester = lineBreakSuggester
    }

    func invalidateTypesetText(in line: some Line) {
        map.removeValue(forKey: line.id)
    }

    func typesetText(in line: some Line, toYOffset yOffset: CGFloat) -> [TypesetLineFragment] {
        lineTypesetter(typesetting: line).typesetText(toYOffset: yOffset)
    }

    func typesetText(in line: some Line, toLocation location: Int) -> [TypesetLineFragment] {
        lineTypesetter(typesetting: line).typesetText(toLocation: location)
    }
}

private extension Typesetter {
    private func lineTypesetter(typesetting line: some Line) -> LineTypesetter {
        if let typesetter = map[line.id] {
            return typesetter
        }
        let range = NSRange(location: line.location, length: line.totalLength)
        guard let attributedString = stringView.attributedSubstring(in: range) else {
            fatalError("Failed reading attributed string to typeset")
        }
        let typesetter = LineTypesetter(
            state: state,
            attributedString: attributedString,
            lineBreakSuggester: lineBreakSuggester
        )
        map[line.id] = typesetter
        return typesetter
    }
}
