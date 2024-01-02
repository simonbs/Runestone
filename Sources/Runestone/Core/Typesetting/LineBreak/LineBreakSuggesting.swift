import CoreText
import Foundation

protocol LineBreakSuggesting {
    func suggestLineBreak(
        after location: Int,
        in attributedString: NSAttributedString,
        typesetUsing typesetter: CTTypesetter
    ) -> Int
}
