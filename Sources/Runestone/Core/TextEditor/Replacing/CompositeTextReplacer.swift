import Foundation

struct CompositeTextReplacer: TextReplacing {
    private let textReplacers: [any TextReplacing]

    init(_ textReplacers: any TextReplacing...) {
        self.textReplacers = textReplacers
    }

    func replaceText(in range: NSRange, with newText: String) {
        for textReplacer in textReplacers {
            textReplacer.replaceText(in: range, with: newText)
        }
    }
}
