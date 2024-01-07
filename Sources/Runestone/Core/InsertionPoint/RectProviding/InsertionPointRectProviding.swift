import CoreGraphics

protocol InsertionPointRectProviding {
    func insertionPointRect(atLocation location: Int) -> CGRect
}
