import QuartzCore

struct LineFragmentVisibleLinesRenderer<LineType: Line>: VisibleLinesRendering {
    typealias State = TextContainerInsetReadable

    let state: State
    let hostLayer: CALayer
    let renderer: LineFragmentRendering

    private let layerQueue = ReuseQueue<LineFragmentID, LineFragmentLayer<LineType>>()

    func renderVisibleLines(_ visibleLines: [VisibleLine<LineType>]) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let visibleIDs: Set<LineFragmentID> = visibleLines.reduce(into: []) {
            $0.formUnion(Set($1.lineFragments.map(\.id)))
        }
        let disappearedIDs = Set(layerQueue.activeValues.keys).subtracting(visibleIDs)
        layerQueue.enqueueValues(withKeys: disappearedIDs)
        for visibleLine in visibleLines {
            let line = visibleLine.line
            for lineFragment in visibleLine.lineFragments {
                let layer = layerQueue.dequeueValue(forKey: lineFragment.id)
                let originX = state.textContainerInset.left
                let originY = state.textContainerInset.top + line.yPosition + lineFragment.yPosition
                let origin = CGPoint(x: originX, y: originY)
                layer.line = line
                layer.lineFragment = lineFragment
                layer.renderer = renderer
                layer.frame = CGRect(origin: origin, size: lineFragment.scaledSize)
                hostLayer.insertSublayer(layer, at: 0)
                layer.displayIfNeeded()
            }
        }
        CATransaction.commit()
    }
}
