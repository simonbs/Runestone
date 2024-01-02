import Foundation

struct ManagedLineFactory: LineFactory {
    let typesetter: Typesetting

    func makeLine(estimatingHeightTo estimatedHeight: CGFloat) -> ManagedLine {
        ManagedLine(typesetter: typesetter, estimatedHeight: estimatedHeight)
    }
}

