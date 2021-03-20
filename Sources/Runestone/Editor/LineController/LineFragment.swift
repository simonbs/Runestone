//
//  LineFragment.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

import CoreText

struct LineFragmentID: Identifiable, Hashable {
    let id: String

    init(lineId: String, lineFragmentIndex: Int) {
        self.id = "\(lineId)[\(lineFragmentIndex)]"
    }
}

extension LineFragmentID: CustomDebugStringConvertible {
    var debugDescription: String {
        return id
    }
}

final class LineFragment {
    let id: LineFragmentID
    let line: CTLine
    let descent: CGFloat
    let baseSize: CGSize
    let scaledSize: CGSize
    let yPosition: CGFloat

    init(id: LineFragmentID, line: CTLine, descent: CGFloat, baseSize: CGSize, scaledSize: CGSize, yPosition: CGFloat) {
        self.id = id
        self.line = line
        self.descent = descent
        self.baseSize = baseSize
        self.scaledSize = scaledSize
        self.yPosition = yPosition
    }
}

extension LineFragment: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[LineFragment id=\(id) descent=\(descent) baseSize=\(baseSize) scaledSize=\(scaledSize) yPosition=\(yPosition)]"
    }
}
