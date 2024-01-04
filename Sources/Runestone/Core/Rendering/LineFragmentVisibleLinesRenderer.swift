import QuartzCore


import UIKit

struct LineFragmentVisibleLinesRenderer<LineType: Line>: VisibleLinesRendering {
    let hostLayer: CALayer
    let renderer: LineFragmentRendering

    private let layerQueue = ReuseQueue<LineFragmentID, LineFragmentLayer<LineType>>()

    func renderVisibleLines(_ visibleLines: [VisibleLine<LineType>]) {
        let visibleIDs: Set<LineFragmentID> = visibleLines.reduce(into: []) {
            $0.formUnion(Set($1.lineFragments.map(\.id)))
        }
        let disappearedIDs = Set(layerQueue.activeValues.keys).subtracting(visibleIDs)
        layerQueue.enqueueValues(withKeys: disappearedIDs)
        for visibleLine in visibleLines {
            let line = visibleLine.line
            for lineFragment in visibleLine.lineFragments {
                let layer = layerQueue.dequeueValue(forKey: lineFragment.id)
                let origin = CGPoint(x: 0, y: line.yPosition + lineFragment.yPosition)
                layer.line = line
                layer.lineFragment = lineFragment
                layer.renderer = renderer
                layer.frame = CGRect(origin: origin, size: lineFragment.scaledSize)
                layer.backgroundColor = UIColor.red.cgColor
                hostLayer.insertSublayer(layer, at: 0)
            }
        }
    }
}
