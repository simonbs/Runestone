import Foundation

protocol LineTextRendering {
    associatedtype LineType: Line
    func renderVisibleText(in line: LineType)
    func render(_ line: LineType, toLocation location: Int)
}
