import Foundation

protocol LineTypesetting {
    func typesetText(toYOffset yOffset: CGFloat) -> [TypesetLineFragment]
    func typesetText(toLocation location: Int) -> [TypesetLineFragment]
}
