import Foundation
import RunestoneEngine
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
        TokenBackgroundMapping.stringForTypesetting(input, backgroundColorKey: .backgroundColor)
    }
}

extension LineTypesetter {
    convenience init(lineID: String) {
        self.init(lineID: lineID, preparation: UIKitLineTypesetterPreparation())
    }
}
