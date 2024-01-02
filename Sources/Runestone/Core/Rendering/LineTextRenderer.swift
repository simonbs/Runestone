import Foundation

struct LineTextRenderer<ViewportType: Viewport, LineType: Line>: LineTextRendering {
    let viewport: ViewportType

    func renderVisibleText(in line: LineType) {
        line.typesetText(toYOffset: viewport.maxY)
        let lineFragments = line.lineFragments(in: viewport.rect)
        print(lineFragments)
    }

    func render(_ line: LineType, toLocation location: Int) {
        line.typesetText(toLocation: location)
    }
}
