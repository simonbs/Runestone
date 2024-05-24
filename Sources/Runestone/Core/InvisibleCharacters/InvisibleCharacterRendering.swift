import CoreGraphics

protocol InvisibleCharacterRendering {
    func canRenderInvisibleCharacter<LineType: Line>(
        atLocation location: Int,
        alignedTo lineFragment: LineType.LineFragmentType,
        in line: LineType
    ) -> Bool
    func renderInvisibleCharacter<LineType: Line>(
        atLocation location: Int,
        alignedTo lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    )
}
