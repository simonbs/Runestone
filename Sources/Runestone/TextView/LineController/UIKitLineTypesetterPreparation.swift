import Foundation
import UIKit

/// Retains the iOS-specific font, color, and optimized reuse policies.
struct UIKitLineTypesetterPreparation: LineTypesetterPreparation {
    func prepare(_ input: NSAttributedString) -> PreparedLineTypesetterInput? {
        guard let context = UnbrokenLineBreakContext.make(for: input) else {
            return nil
        }
        return PreparedLineTypesetterInput(text: context.text, run: context.run)
    }

    func reusablePrefixCount(from old: NSAttributedString, to new: NSAttributedString,
                             fragments: [LineFragment], limit: Int) -> Int {
        LinePrefixReuse.count(from: old, to: new, fragments: fragments, limit: limit)
    }

    func stringForTypesetting(_ input: NSAttributedString) -> NSAttributedString {
        // Paint token backgrounds before search and marked-text highlights.
        // Preserve the original attributes for StringSyntaxHighlighter clients.
        var copy: NSMutableAttributedString?
        input.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: input.length)) { value, range, _ in
            guard let value else {
                return
            }
            if copy == nil {
                copy = NSMutableAttributedString(attributedString: input)
            }
            copy?.removeAttribute(.backgroundColor, range: range)
            copy?.addAttribute(.tokenBackgroundColor, value: value, range: range)
        }
        return copy ?? input
    }
}

extension LineTypesetter {
    convenience init(lineID: String) {
        self.init(lineID: lineID, preparation: UIKitLineTypesetterPreparation())
    }
}
