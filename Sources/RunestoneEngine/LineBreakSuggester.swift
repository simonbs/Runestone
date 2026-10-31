import CoreText
import Foundation

struct LineBreakSuggester {
    let lineBreakMode: LineBreakMode
    let typesetter: CTTypesetter
    let attributedString: NSAttributedString
    let constrainingWidth: CGFloat

    func suggestLineBreak(startingAt startOffset: Int) -> Int {
        switch lineBreakMode {
        case .byWordWrapping:
            let lineBreakSuggester = WordWrappingLineBreakSuggester(
                typesetter: typesetter,
                attributedString: attributedString,
                constrainingWidth: constrainingWidth
            )
            return lineBreakSuggester.suggestLineBreak(startingAt: startOffset)
        case .byCharWrapping:
            let lineBreakSuggester = CharacterLineBreakSuggester(
                typesetter: typesetter,
                attributedString: attributedString,
                constrainingWidth: constrainingWidth
            )
            return lineBreakSuggester.suggestLineBreak(startingAt: startOffset)
        }
    }
}
