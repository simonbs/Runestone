import Foundation

struct StringViewTextReplacer<StringViewType: StringView>: TextReplacing {
    let stringView: StringViewType

    func replaceText(in range: NSRange, with newText: String) {
        stringView.replaceText(in: range, with: newText)
    }
}
