struct SizeTrackingVisibleLinesRenderer<
    VisibleLinesRenderer: VisibleLinesRendering,
    LineManagerType: LineManaging
>: VisibleLinesRendering {
    typealias LineType = VisibleLinesRenderer.LineType

    let visibleLinesRenderer: VisibleLinesRenderer
    let contentSizeService: ContentSizeService<LineManagerType>

    func renderVisibleLines(_ visibleLines: [VisibleLine<LineType>]) {
        visibleLinesRenderer.renderVisibleLines(visibleLines)
        for visibleLine in visibleLines {
            let line = visibleLine.line
            contentSizeService.setSize(line.size, ofLineWithID: line.id)
        }
    }
}
