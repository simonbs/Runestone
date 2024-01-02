import Foundation

struct RenderingTextReplacer: TextReplacing {
    let textRenderer: TextRendering

    func replaceText(in range: NSRange, with newText: String) {
        textRenderer.renderVisibleText()
    }
}
