import Foundation

protocol Typesetting {
    func invalidateTypesetText(in line: some Line)
    func typesetText(in line: some Line, toYOffset yOffset: CGFloat) -> [TypesetLineFragment]
    func typesetText(in line: some Line, toLocation location: Int) -> [TypesetLineFragment]
}
