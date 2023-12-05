import Foundation

struct LayoutingTextReplacer: TextReplacing {
    let textLayouter: TextLayouting

    func replaceText(in range: NSRange, with newText: String) {
        textLayouter.layoutText()
    }
}
