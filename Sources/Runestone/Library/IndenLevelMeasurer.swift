//
//  IndentLevelMeasurer.swift
//  
//
//  Created by Simon on 28/03/2021.
//

import Foundation

final class IndentLevelMeasurer {
    private let stringView: StringView

    init(stringView: StringView) {
        self.stringView = stringView
    }

    func indentLevel(of line: DocumentLineNode, tabLength: Int) -> Int {
        var indentLength = 0
        let location = line.location
        for i in 0 ..< line.data.totalLength {
            let range = NSRange(location: location + i, length: 1)
            let str = stringView.substring(in: range).first
            if str == Symbol.Character.tab {
                indentLength += tabLength - (indentLength % tabLength)
            } else if str == Symbol.Character.space {
                indentLength += 1
            } else {
                break
            }
        }
        return indentLength / tabLength
    }
}
