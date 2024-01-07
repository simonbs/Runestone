import CoreGraphics

struct UnderlineInsertionPointProvider<
    StringViewType: StringView,
    CharacterBoundsProvidingType: CharacterBoundsProviding
>: InsertionPointRectProviding {
    let stringView: StringViewType
    let characterBoundsProvider: CharacterBoundsProvidingType
    
    func insertionPointRect(atLocation location: Int) -> CGRect {
        .null
    }
}
