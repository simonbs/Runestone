import Foundation

struct LineBreakHandlingInsertionPointRectProvider<
    LineManagerType: LineManaging
>: InsertionPointRectProviding {
    typealias State = ThemeReadable

    private let insertionPointRectProvider: InsertionPointRectProviding
    private let state: State
    private let stringView: StringView
    private let lineManager: LineManagerType

    init(
        decorating insertionPointRectProvider: InsertionPointRectProviding,
        state: State,
        stringView: StringView,
        lineManager: LineManagerType
    ) {
        self.insertionPointRectProvider = insertionPointRectProvider
        self.state = state
        self.stringView = stringView
        self.lineManager = lineManager
    }

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
