import Foundation

struct ManagedLineFactory<StringViewType: StringView>: LineFactory {
    typealias State = EstimatedLineHeightReadable & LineTypesetter.State

    let state: State
    let stringView: StringViewType
    let viewport: Viewport

    func makeLine() -> ManagedLine<StringViewType> {
        let typesetter = LineTypesetter<StringViewType, ManagedLine<StringViewType>>(
            state: state,
            stringView: stringView, 
            viewport: viewport
        )
        let managedLine = ManagedLine(typesetter: typesetter, estimatedHeight: state.estimatedLineHeight)
        typesetter.line = managedLine
        return managedLine
    }
}

