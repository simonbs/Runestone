import Foundation

typealias LineID = UUID

protocol Line: Equatable {
    associatedtype LineFragmentType: LineFragment
    var id: LineID { get }
    var index: Int { get }
    var location: Int { get }
    var length: Int { get }
    var totalLength: Int { get }
    var delimiterLength: Int { get }
    var yPosition: CGFloat { get }
    var height: CGFloat { get }
    var lineFragments: [LineFragmentType] { get }
    var numberOfLineFragments: Int { get }
    func lineFragment(containingCharacterAt location: Int) -> LineFragmentType
    func lineFragment(atIndex index: Int) -> LineFragmentType
    func location(closestTo localPoint: CGPoint) -> Int
}

extension Line {
    var totalLength: Int {
        length + delimiterLength
    }
}
