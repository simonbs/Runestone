import Foundation

struct ManagedLineFactory: LineFactory {
    typealias State = EstimatedLineHeightReadable & LineTypesetter.State

    let state: State
    let stringView: StringView
    let viewport: Viewport

    func makeLine() -> ManagedLine {
        let typesetter = LineTypesetter<ManagedLine>(state: state, stringView: stringView, viewport: viewport)
        let managedLine = ManagedLine(typesetter: typesetter, estimatedHeight: state.estimatedLineHeight)
        typesetter.line = managedLine
        return managedLine
    }
}

