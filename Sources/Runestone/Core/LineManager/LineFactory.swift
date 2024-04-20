import Foundation

protocol LineFactory {
    associatedtype LineType: Line
    func makeLine() -> LineType
}
