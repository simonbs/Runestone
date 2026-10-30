import Foundation

struct TextInsets: Equatable {
    static let zero = Self(top: 0, left: 0, bottom: 0, right: 0)

    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat
}

enum TextWritingDirection: Equatable {
    case natural
    case leftToRight
    case rightToLeft
}

struct SelectionRectangle: Equatable {
    let rect: CGRect
    let writingDirection: TextWritingDirection
    let containsStart: Bool
    let containsEnd: Bool
    let isVertical: Bool

    init(rect: CGRect, writingDirection: TextWritingDirection, containsStart: Bool,
         containsEnd: Bool, isVertical: Bool = false) {
        self.rect = rect
        self.writingDirection = writingDirection
        self.containsStart = containsStart
        self.containsEnd = containsEnd
        self.isVertical = isVertical
    }
}
