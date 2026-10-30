import Foundation
import RunestoneEngine

/// An optional fast-path span whose boundaries are expressed in UTF-16 units.
struct LineTypesetterRun {
    let range: Range<Int>
    let allowsInitialOffset: Bool
}

struct PreparedLineTypesetterInput {
    let text: NSAttributedString
    let run: LineTypesetterRun
}

/// Platform-owned preparation and optimization policy for Core Text typesetting.
protocol LineTypesetterPreparation {
    func prepare(_ input: NSAttributedString) -> PreparedLineTypesetterInput?
    func reusablePrefixCount(from old: NSAttributedString, to new: NSAttributedString,
                             fragments: [LineFragment], limit: Int) -> Int
    func stringForTypesetting(_ input: NSAttributedString) -> NSAttributedString
}

/// Uses ordinary Core Text line breaking without platform-specific optimizations.
struct DefaultLineTypesetterPreparation: LineTypesetterPreparation {
    var backgroundColorKey: NSAttributedString.Key?

    init(backgroundColorKey: NSAttributedString.Key? = nil) {
        self.backgroundColorKey = backgroundColorKey
    }

    func prepare(_ input: NSAttributedString) -> PreparedLineTypesetterInput? { nil }

    func reusablePrefixCount(from old: NSAttributedString, to new: NSAttributedString,
                             fragments: [LineFragment], limit: Int) -> Int { 0 }

    func stringForTypesetting(_ input: NSAttributedString) -> NSAttributedString {
        guard let backgroundColorKey else { return input }
        return TokenBackgroundMapping.stringForTypesetting(input, backgroundColorKey: backgroundColorKey)
    }
}
