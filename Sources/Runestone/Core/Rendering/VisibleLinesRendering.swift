protocol VisibleLinesRendering {
    associatedtype LineType: Line
    func renderVisibleLines(_ visibleLines: [VisibleLine<LineType>])
}
