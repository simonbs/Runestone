import CoreGraphics

struct BlockInsertionPointProvider<
    StringViewType: StringView,
    CharacterBoundsProvidingType: CharacterBoundsProviding
>: InsertionPointRectProviding {
    let stringView: StringViewType
    let characterBoundsProvider: CharacterBoundsProvidingType
    
    func insertionPointRect(atLocation location: Int) -> CGRect {
        .null
    }
}
