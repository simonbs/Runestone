import Foundation

struct LineFragmentEndHandlingInsertionPointRectProvider<
    LineManagerType: LineManaging
>: InsertionPointRectProviding {
    private let insertionPointRectProvider: InsertionPointRectProviding
    private let lineManager: LineManagerType

    init(
        decorating insertionPointRectProvider: InsertionPointRectProviding,
        lineManager: LineManagerType
    ) {
        self.insertionPointRectProvider = insertionPointRectProvider
        self.lineManager = lineManager
    }

    func insertionPointRect(atLocation location: Int) -> CGRect {
        if shouldMoveToNextLineFragment(forInsertionPointAtLocation: location) {
            return insertionPointRectProvider.insertionPointRect(atLocation: location + 1)
        } else {
            return insertionPointRectProvider.insertionPointRect(atLocation: location)
        }
    }
}

private extension LineFragmentEndHandlingInsertionPointRectProvider {
    private func shouldMoveToNextLineFragment(forInsertionPointAtLocation location: Int) -> Bool {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return false
        }
        guard line.numberOfLineFragments > 0 else {
            return false
        }
        let lineLocation = line.location
        let lineFragment = line.lineFragment(containingLocation: location - lineLocation)
        guard lineFragment.index > 0 else {
            return false
        }
        return location == lineLocation + lineFragment.range.location
    }
}
