import CoreText
import Foundation

struct LineBreakSuggester: LineBreakSuggesting {
    typealias State = IsLineWrappingEnabledReadable & LineBreakModeReadable

    private let state: State
    private let maximumLineFragmentWidthProvider: MaximumLineFragmentWidthProviding
    private var lineBreakSuggester: LineBreakSuggesting {
        switch state.lineBreakMode {
        case .byWordWrapping:
            WordWrappingLineBreakSuggester(
                maximumLineFragmentWidthProvider: maximumLineFragmentWidthProvider
            )
        case .byCharWrapping:
            CharacterLineBreakSuggester(
                maximumLineFragmentWidthProvider: maximumLineFragmentWidthProvider
            )
        }
    }

    init(state: State, maximumLineFragmentWidthProvider: MaximumLineFragmentWidthProviding) {
        self.state = state
        self.maximumLineFragmentWidthProvider = maximumLineFragmentWidthProvider
    }

    func suggestLineBreak(
        after location: Int,
        in attributedString: NSAttributedString,
        typesetUsing typesetter: CTTypesetter
    ) -> Int {
        guard state.isLineWrappingEnabled else {
            return attributedString.length
        }
        return lineBreakSuggester.suggestLineBreak(
            after: location,
            in: attributedString,
            typesetUsing: typesetter
        )
    }
}
