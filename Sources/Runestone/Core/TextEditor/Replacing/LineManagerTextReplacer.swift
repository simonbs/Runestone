import Foundation

struct LineManagerTextReplacer<LineManagerType: LineManager>: TextReplacing {
    let lineManager: LineManagerType

    func replaceText(in range: NSRange, with newText: String) {
        _ = lineManager.removeText(in: range)
        _ = lineManager.insertText(newText as NSString, at: range.location)
    }
}
