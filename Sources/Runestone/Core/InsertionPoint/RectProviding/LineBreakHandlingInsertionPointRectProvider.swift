import Foundation

struct LineBreakHandlingInsertionPointRectProvider<
    LineManagerType: LineManaging
>: InsertionPointRectProviding {
    typealias State = ThemeReadable

    let insertionPointRectProvider: InsertionPointRectProviding
    let state: State
    let stringView: StringView
    let lineManager: LineManagerType

    func insertionPointRect(atLocation location: Int) -> CGRect {
        let range = NSRange(location: location - 1, length: 1)
        guard let string = stringView.substring(in: range) else {
            return insertionPointRectProvider.insertionPointRect(atLocation: location)
        }
        guard LineEnding(symbol: string) != nil else {
            return insertionPointRectProvider.insertionPointRect(atLocation: location)
        }
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return insertionPointRectProvider.insertionPointRect(atLocation: location)
        }
        let estimatedLineHeight = state.theme.estimatedCharacterSize.height
        return CGRect(x: 0, y: line.yPosition, width: 3, height: estimatedLineHeight)
    }
}
