import Foundation

struct RenderingTextReplacer: TextReplacing {
    let viewportRenderer: ViewportRendering

    func replaceText(in range: NSRange, with newText: String) {
        viewportRenderer.renderViewport()
    }
}
