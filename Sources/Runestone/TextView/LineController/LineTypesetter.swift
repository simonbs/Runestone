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
    var constrainingWidth: CGFloat = 0
    var lineFragmentHeightMultiplier: CGFloat = 1
    private(set) var lineFragments: [LineFragment] = []
    private(set) var maximumLineWidth: CGFloat = 0
    var bestGuessNumberOfLineFragments: Int {
        if startOffset >= stringLength {
            return lineFragments.count
        } else {
            let charactersPerLineFragment = Double(startOffset) / Double(lineFragments.count)
            let charactersRemaining = stringLength - startOffset
            let remainingNumberOfLineFragments = Int(ceil(Double(charactersRemaining) / charactersPerLineFragment))
            return lineFragments.count + remainingNumberOfLineFragments
        }
    }
    var isFinishedTypesetting: Bool {
        return startOffset >= stringLength
    }

    private let lineID: String
    private var stringLength = 0
    private var typesetter: CTTypesetter?
    private var lineFragmentsMap: [LineFragmentID: Int] = [:]
    private var startOffset = 0
    private var nextYPosition: CGFloat = 0
    private var lineFragmentIndex = 0

    init(lineID: String) {
        self.lineID = lineID
    }

    func reset() {
        lineFragments = []
        maximumLineWidth = 0
        stringLength = 0
        typesetter = nil
        lineFragmentsMap = [:]
        startOffset = 0
        nextYPosition = 0
        lineFragmentIndex = 0
    }

    func prepareToTypeset(_ attributedString: CFAttributedString) {
        stringLength = CFAttributedStringGetLength(attributedString)
        typesetter = CTTypesetterCreateWithAttributedString(attributedString)
    }

    @discardableResult
    func typesetLineFragments(in rect: CGRect) -> [LineFragment] {
        if let typesetter = typesetter {
            let typesetResult = self.typesetLineFragments(in: rect, using: typesetter, stringLength: stringLength)
            updateState(from: typesetResult)
            return typesetResult.lineFragments
        } else {
            return []
        }
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
    private func updateState(from typesetResult: TypesetResult) {
        lineFragments.append(contentsOf: typesetResult.lineFragments)
        for (id, index) in typesetResult.lineFragmentsMap {
            lineFragmentsMap[id] = index
        }
        maximumLineWidth = max(maximumLineWidth, typesetResult.maximumLineWidth)
    }

    private func createAttributedString(from string: String) -> CFAttributedString? {
        if let attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, string.utf16.count) {
            CFAttributedStringReplaceString(attributedString, CFRangeMake(0, 0), string as CFString)
            return attributedString
        } else {
            return nil
        }
    }

    private func typesetLineFragments(in rect: CGRect, using typesetter: CTTypesetter, stringLength: Int) -> TypesetResult {
        guard constrainingWidth > 0 else {
            return TypesetResult(lineFragments: [], lineFragmentsMap: [:], maximumLineWidth: 0)
        }
        var maximumLineWidth: CGFloat = 0
        var lineFragments: [LineFragment] = []
        var lineFragmentsMap: [LineFragmentID: Int] = [:]
        while startOffset < stringLength && nextYPosition < rect.maxY {
            let length = CTTypesetterSuggestLineBreak(typesetter, startOffset, Double(constrainingWidth))
            let range = CFRangeMake(startOffset, length)
            let lineFragment = makeLineFragment(for: range, in: typesetter, lineFragmentIndex: lineFragmentIndex, yPosition: nextYPosition)
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

    private func makeLineFragment(for range: CFRange, in typesetter: CTTypesetter, lineFragmentIndex: Int, yPosition: CGFloat) -> LineFragment {
        let line = CTTypesetterCreateLine(typesetter, range)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let height = ascent + descent + leading
        let baseSize = CGSize(width: width, height: height)
        let scaledSize = CGSize(width: width, height: height * lineFragmentHeightMultiplier)
        let id = LineFragmentID(lineId: lineID, lineFragmentIndex: lineFragmentIndex)
        let nsRange = NSRange(location: range.location, length: range.length)
        return LineFragment(
            id: id,
            index: lineFragmentIndex,
            range: nsRange,
            line: line,
            descent: descent,
            baseSize: baseSize,
            scaledSize: scaledSize,
            yPosition: yPosition)
    }
}
