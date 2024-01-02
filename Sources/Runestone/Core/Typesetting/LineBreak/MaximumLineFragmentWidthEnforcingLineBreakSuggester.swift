import CoreText
import Foundation

struct MaximumLineFragmentWidthEnforcingLineBreakSuggester: LineBreakSuggesting {
    private let lineBreakSuggester: LineBreakSuggesting
    private let maximumLineFragmentWidthProvider: MaximumLineFragmentWidthProviding

    init(
        decorating lineBreakSuggester: LineBreakSuggesting,
        maximumLineFragmentWidthProvider: MaximumLineFragmentWidthProviding
    ) {
        self.lineBreakSuggester = lineBreakSuggester
        self.maximumLineFragmentWidthProvider = maximumLineFragmentWidthProvider
    }

    func suggestLineBreak(
        after location: Int,
        in attributedString: NSAttributedString,
        typesetUsing typesetter: CTTypesetter
    ) -> Int {
        // Decorated suggester uses CTTypesetterSuggestLineBreak which may return lines that are wider
        // than than the supplied maximum width. In that case we keep removing charactears from the line
        // until the width of the line is below the maximum width.
        var length = lineBreakSuggester.suggestLineBreak(
            after: location,
            in: attributedString,
            typesetUsing: typesetter
        )
        let range = CFRangeMake(location, length)
        let line = CTTypesetterCreateLine(typesetter, range)
        var width = CTLineGetTypographicBounds(line, nil, nil, nil)
        while length > 0 && width > maximumLineFragmentWidthProvider.maximumLineFragmentWidth {
            length -= 1
            let range = CFRangeMake(location, length)
            let line = CTTypesetterCreateLine(typesetter, range)
            width = CTLineGetTypographicBounds(line, nil, nil, nil)
        }
        return length
    }
}

