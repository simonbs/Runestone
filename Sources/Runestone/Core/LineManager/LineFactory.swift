import Foundation

protocol LineFactory {
    associatedtype LineType: Line
    func makeLine(estimatingHeightTo estimatedHeight: CGFloat) -> LineType
}
