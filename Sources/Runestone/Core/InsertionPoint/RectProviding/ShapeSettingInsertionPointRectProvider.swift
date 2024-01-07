import Foundation

struct ShapeSettingInsertionPointRectProvider<
    LineManagerType: LineManaging,
    StringViewType: StringView,
    CharacterBoundsProvidingType: CharacterBoundsProviding
>: InsertionPointRectProviding {
    typealias State = InsertionPointShapeReadable & ThemeReadable & TextContainerInsetReadable

    let state: State
    let lineManaging: LineManagerType
    let stringView: StringViewType
    let characterBoundsProvider: CharacterBoundsProvidingType

    private var provider: InsertionPointRectProviding {
        switch state.insertionPointShape {
        case .verticalBar:
            VerticalBarInsertionPointProvider(
                state: state,
                stringView: stringView,
                characterBoundsProvider: characterBoundsProvider
            )
        case .underline:
            UnderlineInsertionPointProvider(
                stringView: stringView,
                characterBoundsProvider: characterBoundsProvider
            )
        case .block:
            BlockInsertionPointProvider(
                stringView: stringView,
                characterBoundsProvider: characterBoundsProvider
            )
        }
    }

    func insertionPointRect(atLocation location: Int) -> CGRect {
        provider.insertionPointRect(atLocation: location)
    }
}
