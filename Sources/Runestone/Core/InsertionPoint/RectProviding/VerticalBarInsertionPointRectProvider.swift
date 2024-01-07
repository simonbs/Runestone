import CoreGraphics

struct VerticalBarInsertionPointProvider<
    StringViewType: StringView,
    CharacterBoundsProvidingType: CharacterBoundsProviding
>: InsertionPointRectProviding {
    typealias State = ThemeReadable & TextContainerInsetReadable

    let state: State
    let stringView: StringViewType
    let characterBoundsProvider: CharacterBoundsProvidingType

    private let width: CGFloat = 2

    func insertionPointRect(atLocation location: Int) -> CGRect {
        if let bounds = characterBoundsProvider.boundsOfCharacter(atLocation: location - 1) {
            return CGRect(x: bounds.maxX, y: bounds.minY, width: width, height: bounds.height)
        } else {
            let origin = CGPoint(x: state.textContainerInset.left, y: state.textContainerInset.top)
            let bounds = CGRect(origin: origin, size: state.theme.estimatedCharacterSize)
            return CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height)
        }
    }
}
