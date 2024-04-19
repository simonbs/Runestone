import Foundation

typealias LineID = UUID

protocol Line: Hashable {
    associatedtype LineFragmentType: LineFragment
    var id: LineID { get }
    var index: Int { get }
    var location: Int { get }
    var length: Int { get }
    var totalLength: Int { get }
    var delimiterLength: Int { get }
    var yPosition: CGFloat { get }
    var width: CGFloat { get }
    var height: CGFloat { get }
    var numberOfLineFragments: Int { get }
    func invalidateTypesetText()
    func typesetText(toLocation location: Int)
    func typesetText(toYOffset yOffset: CGFloat)
    func lineFragment(containingLocation location: Int) -> LineFragmentType
    func lineFragment(atIndex index: Int) -> LineFragmentType
    func lineFragments(in rect: CGRect) -> [LineFragmentType]
    func location(closestTo localPoint: CGPoint) -> Int
}

extension Line {
    var totalLength: Int {
        length + delimiterLength
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }
}
