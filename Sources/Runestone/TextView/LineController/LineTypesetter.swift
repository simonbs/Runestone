//
//  LineTypesetter.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

import Foundation
import CoreGraphics
import CoreText

private final class TypesetResult {
    let lineFragments: [LineFragment]
    let lineFragmentsMap: [LineFragmentID: Int]
    let maximumLineWidth: CGFloat

    init(lineFragments: [LineFragment], lineFragmentsMap: [LineFragmentID: Int], maximumLineWidth: CGFloat) {
        self.lineFragments = lineFragments
        self.lineFragmentsMap = lineFragmentsMap
        self.maximumLineWidth = maximumLineWidth
    }
}

final class LineTypesetter {
    var constrainingWidth: CGFloat?
    var lineFragmentHeightMultiplier: CGFloat = 1
    private(set) var maximumLineWidth: CGFloat = 0
    private(set) var lineFragments: [LineFragment] = []

    private let lineID: String
    private var lineFragmentsMap: [LineFragmentID: Int] = [:]

    init(lineID: String) {
        self.lineID = lineID
    }

    func typeset(_ attributedString: CFAttributedString) {
        let stringLength = CFAttributedStringGetLength(attributedString)
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        let typesetResult = self.lineFragments(in: typesetter, stringLength: stringLength)
        lineFragments = typesetResult.lineFragments
        lineFragmentsMap = typesetResult.lineFragmentsMap
        maximumLineWidth = typesetResult.maximumLineWidth
    }

    func lineFragment(withID lineFragmentID: LineFragmentID) -> LineFragment? {
        if let index = lineFragmentsMap[lineFragmentID] {
            return lineFragments[index]
        } else {
            return nil
        }
    }
}

private extension LineTypesetter {
    private func createAttributedString(from string: String) -> CFAttributedString? {
        if let attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, string.utf16.count) {
            CFAttributedStringReplaceString(attributedString, CFRangeMake(0, 0), string as CFString)
            return attributedString
        } else {
            return nil
        }
    }

    private func lineFragments(in typesetter: CTTypesetter, stringLength: Int) -> TypesetResult {
        if let constrainingWidth = constrainingWidth {
            return typesetWrappingLines(in: typesetter, stringLength: stringLength, constrainingWidth: constrainingWidth)
        } else {
            return typesetNonWrappingLine(in: typesetter, stringLength: stringLength)
        }
    }

    private func typesetWrappingLines(in typesetter: CTTypesetter, stringLength: Int, constrainingWidth: CGFloat) -> TypesetResult {
        var nextYPosition: CGFloat = 0
        var startOffset = 0
        var maximumLineWidth: CGFloat = 0
        var lineFragments: [LineFragment] = []
        var lineFragmentsMap: [LineFragmentID: Int] = [:]
        var lineFragmentIndex = 0
        while startOffset < stringLength {
            let length = CTTypesetterSuggestLineBreak(typesetter, startOffset, Double(constrainingWidth))
            let range = CFRangeMake(startOffset, length)
            let lineFragment = createLineFragment(for: range, in: typesetter, yPosition: nextYPosition, lineFragmentIndex: lineFragmentIndex)
            lineFragments.append(lineFragment)
            nextYPosition += lineFragment.scaledSize.height
            startOffset += length
            if lineFragment.scaledSize.width > maximumLineWidth {
                maximumLineWidth = lineFragment.scaledSize.width
            }
            lineFragmentsMap[lineFragment.id] = lineFragmentIndex
            lineFragmentIndex += 1
        }
        return TypesetResult(lineFragments: lineFragments, lineFragmentsMap: lineFragmentsMap, maximumLineWidth: maximumLineWidth)
    }

    private func typesetNonWrappingLine(in typesetter: CTTypesetter, stringLength: Int) -> TypesetResult {
        let range = CFRangeMake(0, stringLength)
        let lineFragment = createLineFragment(for: range, in: typesetter, yPosition: 0, lineFragmentIndex: 0)
        let lineFragmentsMap: [LineFragmentID: Int] = [lineFragment.id: 0]
        return TypesetResult(lineFragments: [lineFragment], lineFragmentsMap: lineFragmentsMap, maximumLineWidth: lineFragment.scaledSize.width)
    }

    private func createLineFragment(for range: CFRange, in typesetter: CTTypesetter, yPosition: CGFloat, lineFragmentIndex: Int) -> LineFragment {
        let line = CTTypesetterCreateLine(typesetter, range)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let height = ascent + descent + leading
        let baseSize = CGSize(width: width, height: height)
        let scaledSize = CGSize(width: width, height: height * lineFragmentHeightMultiplier)
        let id = LineFragmentID(lineId: lineID, lineFragmentIndex: lineFragmentIndex)
        return LineFragment(id: id, line: line, descent: descent, baseSize: baseSize, scaledSize: scaledSize, yPosition: yPosition)
    }
}
