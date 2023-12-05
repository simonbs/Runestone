import Foundation

struct StringViewTextReplacer: TextReplacing {
    let stringView: StringView

    func replaceText(in range: NSRange, with newText: String) {
        stringView.replaceText(in: range, with: newText)
    }
}
